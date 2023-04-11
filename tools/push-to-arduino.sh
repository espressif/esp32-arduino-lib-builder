#!/bin/bash
source ./tools/config.sh

if [ -x $GITHUB_TOKEN ]; then
	echo "ERROR: GITHUB_TOKEN was not defined"
	exit 1
fi

if ! [ -d "$AR_COMPS/arduino" ]; then
	echo "ERROR: Target arduino folder does not exist!"
	exit 1
fi

#
# UPDATE FILES
#

if [ $AR_HAS_COMMIT == "0" ]; then
	# make changes to the files
	echo "Patching files in branch '$AR_NEW_BRANCH_NAME'..."
	ESP32_ARDUINO="$AR_COMPS/arduino" ./tools/copy-to-arduino.sh
	
	cd $AR_COMPS/arduino

	# did any of the files change?
	if [ -n "$(git status --porcelain)" ]; then
		echo "Pushing changes to branch '$AR_NEW_BRANCH_NAME'..."
	    git add . && git commit --message "$AR_NEW_COMMIT_MESSAGE" && git push -u origin $AR_NEW_BRANCH_NAME
		if [ $? -ne 0 ]; then
		    echo "ERROR: Pushing to branch '$AR_NEW_BRANCH_NAME' failed"
			exit 1
		fi
	else
	    echo "No changes in branch '$AR_NEW_BRANCH_NAME'"
	    if [ $AR_HAS_BRANCH == "0" ]; then
	    	echo "Delete created branch '$AR_NEW_BRANCH_NAME'"
	    	git branch -d $AR_NEW_BRANCH_NAME
	    fi
	    exit 0
	fi
fi

#
# CREATE PULL REQUEST
#

if [ "$AR_HAS_PR" == "0" ]; then
	pr_created=`git_create_pr "$AR_NEW_BRANCH_NAME" "$AR_NEW_PR_TITLE" "$AR_PR_TARGET_BRANCH"`
	if [ $pr_created == "0" ]; then
		echo "ERROR: Failed to create PR '$AR_NEW_PR_TITLE': "`echo "$git_create_pr_res" | jq -r '.message'`": "`echo "$git_create_pr_res" | jq -r '.errors[].message'`
		exit 1
	fi
fi

#
# esp32-arduino-libs
#
cd "$AR_ROOT"
IDF_LIBS_DIR="$AR_ROOT/../esp32-arduino-libs"

if [ ! -d "$IDF_LIBS_DIR" ]; then
	echo "Cloning esp32-arduino-libs..."
	git clone "https://github.com/espressif/esp32-arduino-libs.git" "$IDF_LIBS_DIR"
else
	echo "Updating esp32-arduino-libs..."
	git -C "$IDF_LIBS_DIR" fetch && \
	git -C "$IDF_LIBS_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

LIBS_HAS_COMMIT=`git_commit_exists "$IDF_LIBS_DIR" "$AR_NEW_COMMIT_MESSAGE"`
LIBS_HAS_BRANCH=`git_branch_exists "$IDF_LIBS_DIR" "$AR_NEW_BRANCH_NAME"`

if [ "$LIBS_HAS_COMMIT" == "1" ]; then
	echo "Commit '$AR_NEW_COMMIT_MESSAGE' in esp32-arduino-libs Already Exists"
	mkdir -p dist && echo "Commit '$AR_NEW_COMMIT_MESSAGE' Already Exists" > dist/log.txt
	exit 0
fi

if [ "$LIBS_HAS_BRANCH" == "1" ]; then
	echo "Branch '$AR_NEW_BRANCH_NAME' Already Exists"
	echo "Switching to esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	git -C "$IDF_LIBS_DIR" checkout $AR_NEW_BRANCH_NAME
else
	echo "Creating esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	git -C "$IDF_LIBS_DIR" checkout -b $AR_NEW_BRANCH_NAME
fi
if [ $? -ne 0 ]; then
    echo "ERROR: Checkout of branch '$AR_NEW_BRANCH_NAME' failed"
	exit 1
fi

if [ $LIBS_HAS_COMMIT == "0" ]; then
	# make changes to the files
	echo "Patching files in esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	rm -rf $IDF_LIBS_DIR/sdk && cp -Rf $AR_TOOLS/sdk $IDF_LIBS_DIR/
	
	cd $IDF_LIBS_DIR

	# did any of the files change?
	if [ -n "$(git status --porcelain)" ]; then
		echo "Pushing changes to esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	    git add . && git commit --message "$AR_NEW_COMMIT_MESSAGE" && git push -u origin $AR_NEW_BRANCH_NAME
		if [ $? -ne 0 ]; then
		    echo "ERROR: Pushing to branch '$AR_NEW_BRANCH_NAME' failed"
			exit 1
		fi
	else
	    echo "No changes in esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'"
	    if [ $LIBS_HAS_BRANCH == "0" ]; then
	    	echo "Delete created branch '$AR_NEW_BRANCH_NAME'"
	    	git branch -d $AR_NEW_BRANCH_NAME
	    fi
	    exit 0
	fi
fi


exit 0
