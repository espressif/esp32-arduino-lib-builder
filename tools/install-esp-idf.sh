#/bin/bash

source ./tools/config.sh

if ! [ -x "$(command -v $SED)" ]; then
  	echo "ERROR: $SED is not installed! Please install $SED first."
  	exit 1
fi

#
# CLONE ESP-IDF
#

IDF_REPO_URL="https://github.com/tasmota/esp-idf.git"
if [ -z "$IDF_PATH" ]; then
	echo "ESP-IDF is not installed! Installing local copy"
	idf_was_installed="1"
	if ! [ -d esp-idf ]; then
                echo "git clone $IDF_REPO_URL -b $IDF_BRANCH"
		git clone $IDF_REPO_URL -b $IDF_BRANCH
	fi
	export IDF_PATH="$AR_ROOT/esp-idf"
fi

# Next lines redirects ALWAYS to espressif git since this sha1 only exists there!!!
#if [ "$IDF_COMMIT" ]; then
#    git -C "$IDF_PATH" checkout "$IDF_COMMIT"
#    commit_predefined="1"
#fi

export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
export IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD)

#
# SETUP ARDUINO DEPLOY
#

if [ "$GITHUB_EVENT_NAME" == "schedule" ] || [ "$GITHUB_EVENT_NAME" == "repository_dispatch" -a "$GITHUB_EVENT_ACTION" == "deploy" ]; then
	# format new branch name and pr title
	if [ -x $commit_predefined ]; then #commit was not specified at build time
		AR_NEW_BRANCH_NAME="idf-$IDF_BRANCH"
		AR_NEW_COMMIT_MESSAGE="IDF $IDF_BRANCH $IDF_COMMIT"
		AR_NEW_PR_TITLE="IDF $IDF_BRANCH"
	else
		AR_NEW_BRANCH_NAME="idf-$IDF_COMMIT"
		AR_NEW_COMMIT_MESSAGE="IDF $IDF_COMMIT"
		AR_NEW_PR_TITLE="$AR_NEW_COMMIT_MESSAGE"
	fi

	AR_HAS_COMMIT=`git_commit_exists "$AR_COMPS/arduino" "$AR_NEW_COMMIT_MESSAGE"`
	AR_HAS_BRANCH=`git_branch_exists "$AR_COMPS/arduino" "$AR_NEW_BRANCH_NAME"`
	AR_HAS_PR=`git_pr_exists "$AR_NEW_BRANCH_NAME"`

	if [ "$AR_HAS_COMMIT" == "1" ]; then
		echo "Commit '$AR_NEW_COMMIT_MESSAGE' Already Exists"
		exit 0
	fi

	if [ "$AR_HAS_BRANCH" == "1" ]; then
		echo "Branch '$AR_NEW_BRANCH_NAME' Already Exists"
	fi

	if [ "$AR_HAS_PR" == "1" ]; then
		echo "PR '$AR_NEW_PR_TITLE' Already Exists"
	fi

	# setup git for pushing
	git config --global github.user "$GITHUB_ACTOR"
	git config --global user.name "$GITHUB_ACTOR"
	git config --global user.email "$GITHUB_ACTOR@github.com"

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

	export AR_NEW_BRANCH_NAME
	export AR_NEW_COMMIT_MESSAGE
	export AR_NEW_PR_TITLE

	export AR_HAS_COMMIT
	export AR_HAS_BRANCH
	export AR_HAS_PR
fi

#
# UPDATE IDF MODULES
#

if [ -x $idf_was_installed ]; then
	echo "ESP-IDF is already installed at: $IDF_PATH"
else
	git -C $IDF_PATH submodule update --init --recursive
	cd $IDF_PATH && python -m pip install -r requirements.txt
fi
cd "$AR_ROOT"
$IDF_PATH/install.sh
source $IDF_PATH/export.sh
