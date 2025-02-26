#/bin/bash

source ./tools/config.sh

IDF_COMMIT=`github_last_commit "$IDF_REPO" "$IDF_BRANCH"`

if [ -z $IDF_COMMIT ]; then
	echo "Failed to get IDF commit for branch $IDF_BRANCH"
	exit 1
fi

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

LIBS_RELEASE_TAG="idf-"${IDF_BRANCH//\//_}""
LIBS_VERSION_PREFIX="$LIBS_RELEASE_TAG-$IDF_COMMIT-v"
VERSION_COUNTER=1

AR_HAS_BRANCH=`github_branch_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME"`
if [ "$AR_HAS_BRANCH" == "1" ]; then
	LATEST_LIBS_IDF=`github_get_libs_idf "$AR_REPO" "$AR_NEW_BRANCH_NAME" "$AR_NEW_PR_TITLE"`
else
	LATEST_LIBS_IDF=`github_get_libs_idf "$AR_REPO" "$AR_BRANCH" "$AR_NEW_PR_TITLE"`
fi

echo "Current IDF commit: $IDF_COMMIT"
echo "Latest IDF commit in $AR_BRANCH of $AR_REPO: $LATEST_LIBS_IDF"

AR_HAS_COMMIT=`if [ "$LATEST_LIBS_IDF" == "$IDF_COMMIT" ]; then echo "1"; else echo "0"; fi`
AR_HAS_PR=`github_pr_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME"`

LIBS_RELEASE_ID=`github_release_id "$AR_LIBS_REPO" "$LIBS_RELEASE_TAG"`
LIBS_HAS_RELEASE=`if [ -n "$LIBS_RELEASE_ID" ]; then echo "1"; else echo "0"; fi`

if [ "$GITHUB_EVENT_NAME" == "workflow_dispatch" ]; then
	echo "Workflow dispatch event. Generating new libs."
	while true; do
		LIBS_ASSET_ID=`github_release_asset_id "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "esp32-arduino-libs-$LIBS_VERSION_PREFIX$VERSION_COUNTER.zip"`
		if [ -n "$LIBS_ASSET_ID" ]; then
			VERSION_COUNTER=$((VERSION_COUNTER+1))
		else
			break
		fi
	done
else
	LIBS_ASSET_ID=`github_release_asset_id "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "esp32-arduino-libs-$LIBS_VERSION_PREFIX$VERSION_COUNTER.zip"`
fi

LIBS_VERSION="$LIBS_VERSION_PREFIX$VERSION_COUNTER"
LIBS_HAS_ASSET=`if [ -n "$LIBS_ASSET_ID" ]; then echo "1"; else echo "0"; fi`

export IDF_COMMIT

export AR_NEW_BRANCH_NAME
export AR_NEW_COMMIT_MESSAGE
export AR_NEW_PR_TITLE

export AR_HAS_COMMIT
export AR_HAS_BRANCH
export AR_HAS_PR

export LIBS_RELEASE_TAG
export LIBS_VERSION
export LIBS_RELEASE_ID
export LIBS_HAS_RELEASE
export LIBS_ASSET_ID
export LIBS_HAS_ASSET

if [ "$LIBS_HAS_RELEASE" == "1" ]; then
	if [ "$LIBS_HAS_ASSET" == "0" ] || [ "$AR_HAS_COMMIT" == "0" ]; then
		echo "Deploy needed"
		export DEPLOY_NEEDED="1"
	else
		echo "Deploy not needed. Skipping..."
		export DEPLOY_NEEDED="0"
	fi
else
	echo "Release for tag \"$LIBS_RELEASE_TAG\" not found. Please create the release first."
	exit 1
fi

echo "IDF_COMMIT: $IDF_COMMIT"
echo "AR_BRANCH: $AR_BRANCH"
echo "AR_NEW_COMMIT_MESSAGE: $AR_NEW_COMMIT_MESSAGE"
echo "AR_NEW_BRANCH_NAME: $AR_NEW_BRANCH_NAME"
echo "AR_NEW_PR_TITLE: $AR_NEW_PR_TITLE"
echo "AR_HAS_COMMIT: $AR_HAS_COMMIT"
echo "AR_HAS_BRANCH: $AR_HAS_BRANCH"
echo "AR_HAS_PR: $AR_HAS_PR"
echo "LIBS_RELEASE_TAG: $LIBS_RELEASE_TAG"
echo "LIBS_VERSION: $LIBS_VERSION"
echo "LIBS_RELEASE_ID: $LIBS_RELEASE_ID"
echo "LIBS_HAS_RELEASE: $LIBS_HAS_RELEASE"
echo "LIBS_ASSET_ID: $LIBS_ASSET_ID"
echo "LIBS_HAS_ASSET: $LIBS_HAS_ASSET"
echo "DEPLOY_NEEDED: $DEPLOY_NEEDED"

if [ ! -x $GITHUB_OUTPUT ]; then
	echo "idf_commit=$IDF_COMMIT" >> "$GITHUB_OUTPUT"
	echo "ar_branch=$AR_BRANCH" >> "$GITHUB_OUTPUT"
	echo "ar_new_commit_message=$AR_NEW_COMMIT_MESSAGE" >> "$GITHUB_OUTPUT"
	echo "ar_new_branch_name=$AR_NEW_BRANCH_NAME" >> "$GITHUB_OUTPUT"
	echo "ar_new_pr_title=$AR_NEW_PR_TITLE" >> "$GITHUB_OUTPUT"
	echo "ar_has_commit=$AR_HAS_COMMIT" >> "$GITHUB_OUTPUT"
	echo "ar_has_branch=$AR_HAS_BRANCH" >> "$GITHUB_OUTPUT"
	echo "ar_has_pr=$AR_HAS_PR" >> "$GITHUB_OUTPUT"
	echo "libs_release_tag=$LIBS_RELEASE_TAG" >> "$GITHUB_OUTPUT"
	echo "libs_version=$LIBS_VERSION" >> "$GITHUB_OUTPUT"
	echo "libs_release_id=$LIBS_RELEASE_ID" >> "$GITHUB_OUTPUT"
	echo "libs_has_release=$LIBS_HAS_RELEASE" >> "$GITHUB_OUTPUT"
	echo "libs_asset_id=$LIBS_ASSET_ID" >> "$GITHUB_OUTPUT"
	echo "libs_has_asset=$LIBS_HAS_ASSET" >> "$GITHUB_OUTPUT"
	echo "deploy_needed=$DEPLOY_NEEDED" >> "$GITHUB_OUTPUT"
fi

