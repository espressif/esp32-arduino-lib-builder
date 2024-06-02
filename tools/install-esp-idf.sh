#/bin/bash

source $SH_ROOT/tools/config.sh

#---------------
# Check for SED
#---------------
if ! [ -x "$(command -v $SED)" ]; then
  	echo "ERROR: $SED is not installed! Please install $SED first."
  	exit 1
fi
#--------------------------------
# Get esp-if 
#--------------------------------
echo "...ESP-IDF installing local copy..."
# Get it by cloning set BRANCH!!!, if not already there
if [ ! -d "$IDF_PATH" ]; then
	echo -e "   cloning $eGI$IDF_REPO_URL$eNO\n   to:$ePF $IDF_PATH $eNO"
	echo -e "   Checkout Branch:$eTG '$IDF_BRANCH' $eNO"
	git clone $IDF_REPO_URL -b $IDF_BRANCH $IDF_PATH --quiet
	idf_was_installed="1"
else
	echo -e "   updating(already thiere)$eGI$IDF_REPO_URL$eNO\n   to:$ePF $IDF_PATH $eNO"
	git -C "$IDF_PATH" fetch --quiet && \
	git -C "$IDF_PATH" pull --ff-only --quiet
	echo -e "   Checkout Branch:$eTG '$IDF_BRANCH' $eNO"
	git -C "$IDF_PATH" checkout $IDF_BRANCH --quiet
fi
# Case when the TAG is set
if [ "$IDF_TAG" ]; then
	echo -e "   checkout tags/$IDF_TAG of: $ePF$IDF_PATH$eNO"
    git -C "$IDF_PATH" checkout "tags/$IDF_TAG" --quiet
    idf_was_installed="1"
# Case when the TAG is set
elif [ "$IDF_COMMIT" ]; then
	echo "   checkout $IDF_COMMIT of: $IDF_PATH"
    git -C "$IDF_PATH" checkout "$IDF_COMMIT" --quiet
    commit_predefined="1"
fi
#----------------------------------
# UPDATE ESP-IDF TOOLS AND MODULES
#----------------------------------
echo "...Updating IDF-Tools and Modules"
echo "   to same path like above"
git -C $IDF_PATH submodule update --init --recursive --quiet
if [ ! -x $idf_was_installed ] || [ ! -x $commit_predefined ]; then
	echo -e "...Installing ESP-IDF Tools"
	echo -e "   with:$eUS $IDF_PATH/install.sh$eNO"	
	if [ $IDF_InstallSilent -eq 1 ] ; then
		echo -e "  $eTG Silent install$eNO - don't use this as long as your not sure install goes without errors!"
		$IDF_PATH/install.sh > /dev/null
	else
		echo "   NOT Silent install - use this if you want to see the output of the install script!"
		$IDF_PATH/install.sh 
	fi

	echo "...export environment variables (IDF_COMMIT) & (IDF_BRANCH)"
	export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
	export IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)

	# Temporarily patch the ESP32-S2 I2C LL driver to keep the clock source
	cd $IDF_PATH
	echo "...Patch difference..."
	patchFile=$(realpath $SH_ROOT'/patches/esp32s2_i2c_ll_master_init.diff')
	patch --quiet -p1 -N -i $patchFile
	cd - > /dev/null
fi
#----------------------------------
# SETUP ESP-IDF ENV
#----------------------------------
echo -e "...Setting up ESP-IDF Environment"
echo -e "   with:$eUS $IDF_PATH/export.sh$eNO"
if [ $IDF_InstallSilent -eq 1 ] ; then
	echo -e "  $eTG Silent install$eNO - don't use this as long as your not sure install goes without errors!"
	source $IDF_PATH/export.sh > /dev/null
else
	echo "   NOT Silent install - use this if you want to see the output of the install script!"
	source $IDF_PATH/export.sh
fi
#----------------------------------
# SETUP ARDUINO DEPLOY
#----------------------------------
echo "...Setting up Arduino Deploy"
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
	LIBS_VERSION="idf-"${IDF_BRANCH//\//_}"-$IDF_COMMIT"

	AR_HAS_COMMIT=`git_commit_exists "$AR_COMPS/arduino" "$AR_NEW_COMMIT_MESSAGE"`
	AR_HAS_BRANCH=`git_branch_exists "$AR_COMPS/arduino" "$AR_NEW_BRANCH_NAME"`
	AR_HAS_PR=`github_pr_exists "$AR_REPO" "$AR_NEW_BRANCH_NAME"`

	LIBS_HAS_COMMIT=`git_commit_exists "$IDF_LIBS_DIR" "$AR_NEW_COMMIT_MESSAGE"`
	LIBS_HAS_BRANCH=`git_branch_exists "$IDF_LIBS_DIR" "$AR_NEW_BRANCH_NAME"`

	if [ "$LIBS_HAS_COMMIT" == "1" ]; then
		echo "Commit '$AR_NEW_COMMIT_MESSAGE' Already Exists in esp32-arduino-libs"
	fi

	if [ "$AR_HAS_COMMIT" == "1" ]; then
		echo "Commit '$AR_NEW_COMMIT_MESSAGE' Already Exists in arduino-esp32"
	fi

	if [ "$LIBS_HAS_COMMIT" == "1" ] && [ "$AR_HAS_COMMIT" == "1" ]; then
		exit 0
	fi

	export AR_NEW_BRANCH_NAME
	export AR_NEW_COMMIT_MESSAGE
	export AR_NEW_PR_TITLE

	export AR_HAS_COMMIT
	export AR_HAS_BRANCH
	export AR_HAS_PR

	export LIBS_VERSION
	export LIBS_HAS_COMMIT
	export LIBS_HAS_BRANCH
fi
