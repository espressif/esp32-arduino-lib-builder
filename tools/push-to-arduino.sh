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

# # format new branch name and pr title
# if [ -x $1 ]; then #commit was not specified at build time
# 	AR_NEW_BRANCH_NAME="idf-$IDF_BRANCH"
# 	AR_NEW_COMMIT_MESSAGE="IDF $IDF_BRANCH $IDF_COMMIT"
# 	AR_NEW_PR_TITLE="IDF $IDF_BRANCH"
# else
# 	AR_NEW_BRANCH_NAME="idf-$IDF_COMMIT"
# 	AR_NEW_COMMIT_MESSAGE="IDF $IDF_COMMIT"
# 	AR_NEW_PR_TITLE="$AR_NEW_COMMIT_MESSAGE"
# fi

# AR_HAS_COMMIT=`git_commit_exists "$AR_COMPS/arduino" "$AR_NEW_COMMIT_MESSAGE"`
# AR_HAS_BRANCH=`git_branch_exists "$AR_COMPS/arduino" "$AR_NEW_BRANCH_NAME"`
# AR_HAS_PR=`git_pr_exists "$AR_NEW_BRANCH_NAME"`

#
# CREATE/UPDATE BRANCH
#

if [ $AR_HAS_COMMIT == "0" ]; then
	cd $AR_COMPS/arduino

	# setup git for pushing
	git config --global github.user "$GITHUB_ACTOR"
	git config --global user.name "$GITHUB_ACTOR"
	git config --global user.email "$GITHUB_ACTOR@github.com"

	# create or checkout the branch
	if [ ! $AR_HAS_BRANCH == "0" ]; then
		echo "Switching to branch '$AR_NEW_BRANCH_NAME'..."
		git checkout $AR_NEW_BRANCH_NAME
	else
		echo "Creating branch '$AR_NEW_BRANCH_NAME'..."
		git checkout -b $AR_NEW_BRANCH_NAME
	fi
	if [ $? -ne 0 ]; then
	    echo "ERROR: Checkour of branch '$AR_NEW_BRANCH_NAME' failed"
		exit 1
	fi

	# make changes to the files
	echo "Patching files in branch '$AR_NEW_BRANCH_NAME'..."
	rm -rf $AR_COMPS/arduino/tools/sdk
	cp -Rf $AR_SDK $AR_COMPS/arduino/tools/sdk
	cp -f $AR_ESPTOOL_PY $AR_COMPS/arduino/tools/esptool.py
	cp -f $AR_GEN_PART_PY $AR_COMPS/arduino/tools/gen_esp32part.py
	cp -f $AR_PLATFORMIO_PY $AR_COMPS/arduino/tools/platformio-build.py
	cp -f $AR_PLATFORM_TXT $AR_COMPS/arduino/platform.txt

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
	pr_created=`git_create_pr "$AR_NEW_BRANCH_NAME" "$AR_NEW_PR_TITLE"`
	if [ $pr_created == "0" ]; then
		echo "ERROR: Failed to create PR '$AR_NEW_PR_TITLE': "`echo "$git_create_pr_res" | jq -r '.message'`": "`echo "$git_create_pr_res" | jq -r '.errors[].message'`
		exit 1
	fi
fi
exit 0
