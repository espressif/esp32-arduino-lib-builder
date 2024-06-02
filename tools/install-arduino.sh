#/bin/bash

source $SH_ROOT/tools/config.sh

echo     "...Component ESP32 Arduino installing/updating local copy...."
# --------------------------------
# arduino-esp32 COMPONENT
# -------------------------------
# Processing for new OPTION -a > AR_PATH is given
if [ ! -z $AR_PATH ]; then
	# ********  Other Arduiono-Component-Path ********
	mkdir -p $AR_PATH # Create the Folder if it does not exist
	# Create a symlink
	if [ ! -e $AR_ROOT/components/arduino ]; then
		# from  <Source>  to  <target> new Folder that's symlink
		ln -s   $AR_PATH      $AR_ROOT/components/arduino > /dev/null
	fi
	# Get Component by cloning, if NOT already there
	if [ ! -d "$AR_COMPS/arduino/package" ]; then
		echo -e "   cloning $eGI$AR_REPO_URL$eNO\n   to:$ePF $AR_PATH $eNO"
		git clone $AR_REPO_URL $AR_PATH --quiet
	else
		echo -e "   updating (already there)$eGI $AR_REPO_URL$eNO\n   to:$ePF $AR_PATH $eNO"
		git -C "$AR_PATH" fetch --quiet && \
		git -C "$AR_PATH"  pull --ff-only --quiet
	fi    
else
	# ********  NORMAL PROCESSING ******** 
	# Get it by cloning, if NOT already there
	if [ ! -d "$AR_COMPS/arduino" ]; then
		echo -e "   cloning $eGI$AR_REPO_URL$eNO\n   to:$ePF $AR_COMPS/arduino$eNO"
		git clone $AR_REPO_URL "$AR_COMPS/arduino" --quiet
	else
		echo -e "   updating (already there)$eGI $AR_REPO_URL$eNO\n   to:$ePF $AR_COMPS/arduino$eNO"
		git -C "$AR_COMPS/arduino" fetch --quiet && \
		git -C "$AR_COMPS/arduino" pull --ff-only --quiet
	fi
fi

# If a desirted branch is NOT set, checkout, fetch & pull it 
if [ -z $AR_BRANCH ]; then
	# Set HEAD_REF if not already set 
	if [ -z $GITHUB_HEAD_REF ]; then
		current_branch=`git branch --show-current --quiet`
	else
		current_branch="$GITHUB_HEAD_REF"
	fi
	echo "...Current Branch: $current_branch"
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
# If a desirted branch IS SET, checkout, fetch & pull it 
if [ "$AR_BRANCH" ]; then
	echo -e "...Checkout, fetch & pull BRANCH:$eTG '$AR_BRANCH'$eNO"
	git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH" --quiet && \
	git -C "$AR_COMPS/arduino" fetch --quiet && \
	git -C "$AR_COMPS/arduino" pull --quiet --ff-only
fi
# $?: Status of the last executed command => 0:OK, 1:Error 
if [ $? -ne 0 ]; then exit 1; fi

# --------------------------------
# Get esp32-arduino-libs COMPONENT
# -------------------------------
if [ ! -d "$IDF_LIBS_DIR" ]; then
	echo -e "...Cloning esp32-arduino-libs...$eGI$AR_LIBS_REPO_URL$eNO"
	echo -e "   to:$ePF $IDF_LIBS_DIR $eNo"
	git clone "$AR_LIBS_REPO_URL" "$IDF_LIBS_DIR" --quiet
else
	echo -e "...Updating existing esp32-arduino-libs...$eGI$AR_LIBS_REPO_URL$eNO"
	echo -e "   in:$ePF $(realpath $IDF_LIBS_DIR) $eNO"
	git -C "$IDF_LIBS_DIR" fetch --quiet && \
	git -C "$IDF_LIBS_DIR" pull --quiet --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi