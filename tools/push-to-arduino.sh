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

# setup git for pushing
git config --global github.user "$GITHUB_ACTOR"
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$GITHUB_ACTOR@github.com"

#
# UPDATE FILES
#

#
# esp32-arduino-libs
#

if [ $LIBS_HAS_COMMIT == "0" ] || [ $AR_HAS_COMMIT == "0" ]; then
	cd "$AR_ROOT"
	# create branch if necessary
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

	# make changes to the files
	echo "Patching files in esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	rm -rf $IDF_LIBS_DIR/* && cp -Rf $AR_TOOLS/esp32-arduino-libs/* $IDF_LIBS_DIR/
	
	cd $IDF_LIBS_DIR
	if [ -f "README.md" ]; then
		rm -rf "README.md"
	fi

	# did any of the files change?
	if [ -n "$(git status --porcelain)" ]; then
		echo "Pushing changes to esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'..."
	    git add . && git commit --message "$AR_NEW_COMMIT_MESSAGE" && git push -u origin $AR_NEW_BRANCH_NAME
		if [ $? -ne 0 ]; then
		    echo "ERROR: Pushing to branch '$AR_NEW_BRANCH_NAME' failed"
			exit 1
		fi
		IDF_LIBS_COMMIT=`git rev-parse --verify HEAD`
		IDF_LIBS_DL_URL="https://codeload.github.com/espressif/esp32-arduino-libs/zip/$IDF_LIBS_COMMIT"
		# ToDo: this URL needs to get into Arduino's package.json

		# Download the file
		filename="esp32-arduino-libs-$IDF_LIBS_COMMIT.zip"
		curl -s -o "$filename" "$IDF_LIBS_DL_URL"

		# Check if the download was successful
		if [ $? -ne 0 ]; then
		  echo "Error downloading file from $IDF_LIBS_DL_URL"
		  exit 1
		fi

		# Calculate the size in bytes and SHA-256 sum
		size=$(stat -c%s "$filename")
		sha256sum=$(sha256sum "$filename" | awk '{print $1}')

		# Clean up the downloaded file
		rm "$filename"

		# Print the results
		echo "Tool: esp32-arduino-libs"
		echo "Version: $LIBS_VERSION"
		echo "URL: $IDF_LIBS_DL_URL"
		echo "File: $filename"
		echo "Size: $size bytes"
		echo "SHA-256: $sha256sum"
		echo "JSON: $AR_OUT/package_esp32_index.template.json"
		cd "$AR_ROOT"
		python3 tools/add_sdk_json.py -j "$AR_OUT/package_esp32_index.template.json" -n "esp32-arduino-libs" -v "$LIBS_VERSION" -u "$IDF_LIBS_DL_URL" -f "$filename" -s "$size" -c "$sha256sum"
		if [ $? -ne 0 ]; then exit 1; fi

	else
	    echo "No changes in esp32-arduino-libs branch '$AR_NEW_BRANCH_NAME'"
	    if [ $LIBS_HAS_BRANCH == "0" ]; then
	    	echo "Delete created branch '$AR_NEW_BRANCH_NAME'"
	    	git branch -d $AR_NEW_BRANCH_NAME
	    fi
	    exit 0
	fi
fi

#
# esp32-arduino
#

if [ $AR_HAS_COMMIT == "0" ]; then
	cd "$AR_ROOT"
	# create or checkout the branch
	if [ ! $AR_HAS_BRANCH == "0" ]; then
		echo "Switching to arduino branch '$AR_NEW_BRANCH_NAME'..."
		git -C "$AR_COMPS/arduino" checkout $AR_NEW_BRANCH_NAME
	else
		echo "Creating arduino branch '$AR_NEW_BRANCH_NAME'..."
		git -C "$AR_COMPS/arduino" checkout -b $AR_NEW_BRANCH_NAME
	fi
	if [ $? -ne 0 ]; then
	    echo "ERROR: Checkout of branch '$AR_NEW_BRANCH_NAME' failed"
		exit 1
	fi

	# make changes to the files
	echo "Patching files in branch '$AR_NEW_BRANCH_NAME'..."
	rm -rf "$AR_COMPS/arduino/package/package_esp32_index.template.json" && cp -f "$AR_OUT/package_esp32_index.template.json" "$AR_COMPS/arduino/package/package_esp32_index.template.json"
	
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

	# CREATE PULL REQUEST
	if [ "$AR_HAS_PR" == "0" ]; then
		echo "Creating PR '$AR_NEW_PR_TITLE'..."
		pr_created=`git_create_pr "$AR_NEW_BRANCH_NAME" "$AR_NEW_PR_TITLE" "$AR_PR_TARGET_BRANCH"`
		if [ $pr_created == "0" ]; then
			echo "ERROR: Failed to create PR '$AR_NEW_PR_TITLE': "`echo "$git_create_pr_res" | jq -r '.message'`": "`echo "$git_create_pr_res" | jq -r '.errors[].message'`
			exit 1
		fi
	else
		echo "PR '$AR_NEW_PR_TITLE' Already Exists"
	fi
fi

exit 0
