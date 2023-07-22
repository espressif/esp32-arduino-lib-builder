#/bin/bash

source ./tools/config.sh

IDF_COMMIT=`github_last_commit "$IDF_REPO" "$IDF_BRANCH"`

if [ -z $GITHUB_HEAD_REF ]; then
	current_branch=`git branch --show-current`
else
	current_branch="$GITHUB_HEAD_REF"
fi

AR_BRANCH="master"
if [[ "$current_branch" != "master" && `github_branch_exists "$AR_REPO" "$current_branch"` == "1" ]]; then
	AR_BRANCH="$current_branch"
else
	AR_BRANCH_NAME="idf-$IDF_BRANCH"
	has_ar_branch=`github_branch_exists "$AR_REPO" "$AR_BRANCH_NAME"`
	if [ "$has_ar_branch" == "1" ]; then
		AR_BRANCH="$AR_BRANCH_NAME"
	else
		has_ar_branch=`github_branch_exists "$AR_REPO" "$AR_PR_TARGET_BRANCH"`
		if [ "$has_ar_branch" == "1" ]; then
			AR_BRANCH="$AR_PR_TARGET_BRANCH"
		fi
	fi
fi

# format new branch name and pr title
AR_NEW_BRANCH_NAME="idf-$IDF_BRANCH"
AR_NEW_COMMIT_MESSAGE="IDF $IDF_BRANCH $IDF_COMMIT"
AR_NEW_PR_TITLE="IDF $IDF_BRANCH"

LIBS_VERSION="idf-"${IDF_BRANCH//\//_}"-$IDF_COMMIT"

AR_HAS_BRANCH=`github_branch_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME"`
if [ "$AR_HAS_BRANCH" == "1" ]; then
	AR_HAS_COMMIT=`github_commit_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME" "$IDF_COMMIT"`
else
	AR_HAS_COMMIT=`github_commit_exists "$AR_REPO" "$AR_BRANCH" "$IDF_COMMIT"`
fi
AR_HAS_PR=`github_pr_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME"`

LIBS_HAS_BRANCH=`github_branch_exists "$AR_LIBS_REPO" "$AR_NEW_BRANCH_NAME"`
LIBS_HAS_COMMIT=`github_commit_exists "$AR_LIBS_REPO" "$AR_NEW_BRANCH_NAME" "$IDF_COMMIT"`

export IDF_COMMIT

export AR_NEW_BRANCH_NAME
export AR_NEW_COMMIT_MESSAGE
export AR_NEW_PR_TITLE

export AR_HAS_COMMIT
export AR_HAS_BRANCH
export AR_HAS_PR

export LIBS_VERSION
export LIBS_HAS_COMMIT
export LIBS_HAS_BRANCH

echo "IDF_COMMIT: $IDF_COMMIT"
echo "AR_BRANCH: $AR_BRANCH"
echo "AR_NEW_COMMIT_MESSAGE: $AR_NEW_COMMIT_MESSAGE"
echo "AR_NEW_BRANCH_NAME: $AR_NEW_BRANCH_NAME"
echo "AR_NEW_PR_TITLE: $AR_NEW_PR_TITLE"
echo "AR_HAS_COMMIT: $AR_HAS_COMMIT"
echo "AR_HAS_BRANCH: $AR_HAS_BRANCH"
echo "AR_HAS_PR: $AR_HAS_PR"
echo "LIBS_VERSION: $LIBS_VERSION"
echo "LIBS_HAS_COMMIT: $LIBS_HAS_COMMIT"
echo "LIBS_HAS_BRANCH: $LIBS_HAS_BRANCH"

if [ ! -x $GITHUB_OUTPUT ]; then
	echo "idf_commit=$IDF_COMMIT" >> "$GITHUB_OUTPUT"
	echo "ar_branch=$AR_BRANCH" >> "$GITHUB_OUTPUT"
	echo "ar_new_commit_message=$AR_NEW_COMMIT_MESSAGE" >> "$GITHUB_OUTPUT"
	echo "ar_new_branch_name=$AR_NEW_BRANCH_NAME" >> "$GITHUB_OUTPUT"
	echo "ar_new_pr_title=$AR_NEW_PR_TITLE" >> "$GITHUB_OUTPUT"
	echo "ar_has_commit=$AR_HAS_COMMIT" >> "$GITHUB_OUTPUT"
	echo "ar_has_branch=$AR_HAS_BRANCH" >> "$GITHUB_OUTPUT"
	echo "ar_has_pr=$AR_HAS_PR" >> "$GITHUB_OUTPUT"
	echo "libs_version=$LIBS_VERSION" >> "$GITHUB_OUTPUT"
	echo "libs_has_commit=$LIBS_HAS_COMMIT" >> "$GITHUB_OUTPUT"
	echo "libs_has_branch=$LIBS_HAS_BRANCH" >> "$GITHUB_OUTPUT"
fi
