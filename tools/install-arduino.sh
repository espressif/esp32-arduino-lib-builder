#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
echo "Updating ESP32 Arduino..."
if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

if [ -z $AR_BRANCH ]; then
	if [ -z $GITHUB_HEAD_REF ]; then
		current_branch=`git branch --show-current`
	else
		current_branch="$GITHUB_HEAD_REF"
	fi
	echo "Current Branch: $current_branch"
	if [[ "$current_branch" != "master" && `git_branch_exists "$AR_COMPS/arduino" "$current_branch"` == "1" ]]; then
		export AR_BRANCH="$current_branch"
	else
		if [ "$IDF_TAG" ]; then #tag was specified at build time
			AR_BRANCH_NAME="idf-$IDF_TAG"
		elif [ "$IDF_COMMIT" ]; then #commit was specified at build time
			AR_BRANCH_NAME="idf-$IDF_COMMIT"
		else
			AR_BRANCH_NAME="idf-$IDF_BRANCH"
		fi
		has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "$AR_BRANCH_NAME"`
		if [ "$has_ar_branch" == "1" ]; then
			export AR_BRANCH="$AR_BRANCH_NAME"
		else
			has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "$AR_PR_TARGET_BRANCH"`
			if [ "$has_ar_branch" == "1" ]; then
				export AR_BRANCH="$AR_PR_TARGET_BRANCH"
			fi
		fi
	fi
fi

if [ "$AR_BRANCH" ]; then
	echo "AR_BRANCH='$AR_BRANCH'"
	git -C "$AR_COMPS/arduino" fetch --all && \
	git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH" && \
	git -C "$AR_COMPS/arduino" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
