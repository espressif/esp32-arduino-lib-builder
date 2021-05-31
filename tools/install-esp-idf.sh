#!/bin/bash

source ./tools/config.sh

if ! [ -x "$(command -v $SED)" ]; then
  	echo "ERROR: $SED is not installed! Please install $SED first."
  	exit 1
fi

#
# CLONE ESP-IDF
#

if [ -z "$IDF_PATH" ]; then
	echo "ESP-IDF is not installed! Installing local copy"
	idf_was_installed="1"
	if ! [ -d esp-idf ]; then
		git clone $IDF_REPO_URL -b $IDF_BRANCH
	fi
	export IDF_PATH="$AR_ROOT/esp-idf"
fi

if [ "$IDF_COMMIT" ]; then
    git -C "$IDF_PATH" checkout "$IDF_COMMIT"
    commit_predefined="1"
fi

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
	git -C $IDF_PATH fetch origin && git -C $IDF_PATH pull origin $IDF_BRANCH
	git -C $IDF_PATH submodule update --init --recursive
else
	git -C $IDF_PATH submodule update --init --recursive
	cd $IDF_PATH && python -m pip install -r requirements.txt && cd "$AR_ROOT"
fi

#
# INSTALL TOOLCHAIN
#

if ! [ -x "$(command -v $IDF_TOOLCHAIN-gcc)" ]; then
  	echo "GCC toolchain is not installed! Installing local copy"

  	if ! [ -d "$IDF_TOOLCHAIN" ]; then
        TC_EXT="tar.gz"
        if [[ "$AR_OS" == "win32" ]]; then
            TC_EXT="zip"
        fi
  		if ! [ -f $IDF_TOOLCHAIN.$TC_EXT ]; then
		  	if [[ "$AR_OS" == "linux32" ]]; then
		  		TC_LINK="$IDF_TOOLCHAIN_LINUX32"
		    elif [[ "$AR_OS" == "linux64" ]]; then
		    	TC_LINK="$IDF_TOOLCHAIN_LINUX64"
		    elif [[ "$AR_OS" == "linux-armel" ]]; then
		    	TC_LINK="$IDF_TOOLCHAIN_LINUX_ARMEL"
			elif [[ "$AR_OS" == "macos" ]]; then
			    TC_LINK="$IDF_TOOLCHAIN_MACOS"
			elif [[ "$AR_OS" == "win32" ]]; then
			    TC_LINK="$IDF_TOOLCHAIN_WIN32"
			else
			    echo "Unsupported OS $OSTYPE"
			    exit 1
			fi
            echo "Downloading $TC_LINK"
			curl -Lk -o $IDF_TOOLCHAIN.$TC_EXT $TC_LINK || exit 1
  		fi
        if [[ "$AR_OS" == "win32" ]]; then
            unzip $IDF_TOOLCHAIN.$TC_EXT || exit 1
        else
            tar zxf $IDF_TOOLCHAIN.$TC_EXT || exit 1
        fi
        rm -rf $IDF_TOOLCHAIN.$TC_EXT
  	fi
  	export PATH="$AR_ROOT/$IDF_TOOLCHAIN/bin:$PATH"
fi
