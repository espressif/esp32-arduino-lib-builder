#/bin/bash

source $SH_ROOT/tools/config.sh
echo     "...Component ESP32 Arduino installing/updating local copy...."
# ------------------------------------------------
# Checks for set Variables AR_COMMIT & AR_BRANCH
# -----------------------------------------------
# Check if COMMIT is set >> ALLWAYS WINs!
if [ ! -z $AR_COMMIT ]; then
	# YES >> AR_COMMIT is SET 
	# Check if BRANCH ist set in addition
	if [ ! -z $AR_BRANCH ]; then
		# YES >> AR_BRANCH is SET
		# Error Message & Exit 
		echo -e "  $eTG ERROR in Arguments for <arduino-esp32>:"
		echo -e "   >> BOTH 'AR_COMMIT' & 'AR_BRANCH' are set. Only ONE of it is allowed!$eNO"
		exit 1
	fi 
fi
# ------------------------------------------------
# Processing for new OPTION -a > AR_PATH is given
# ------------------------------------------------
if [ ! -z $AR_PATH ]; then
	# ********  Other Arduiono-Component-Path ********
	# Check if symbolic link at $AR_ROOT/components/arduino already exists
	if [ ! -L $AR_ROOT/components/arduino ]; then
		# NOT there, than >> Create a symlink 
		# from  <Source>  to  <target> new Folder that's symlink
		ln -s   $AR_PATH      $AR_ROOT/components/arduino > /dev/null
	fi
	# Use the given new location (Symlink)
	ArduionoCOMPS=$AR_PATH
else
	# Use the default location (No Symlink)
	ArduionoCOMPS="$AR_COMPS/arduino" 
fi
# --------------------------------------------
# Get <arduino-esp32> 
#    -by cloning or updating, if already there
# --------------------------------------------
if [ ! -d "$ArduionoCOMPS/package" ]; then
	echo -e "   cloning $eGI$AR_REPO_URL$eNO\n   to: $(shortFP $ArduionoCOMPS)"
	git clone $AR_REPO_URL "$ArduionoCOMPS" --quiet
else
	echo -e "   updating (already there)$eGI $AR_REPO_URL$eNO\n   to: $(shortFP $ArduionoCOMPS)" 
	git -C "$ArduionoCOMPS" fetch --quiet           # Fetch  changes without write it local
	git -C "$ArduionoCOMPS" pull --ff-only --quiet  # Pull > Update local Folder with remote changes
fi
#--------------------------------------------------------
# BRANCH given: checkout 
#--------------------------------------------------------
if [ "$AR_COMMIT" ]; then
	echo -e "...Checkout COMMIT:$eTG '$AR_COMMIT'$eNO"
#	echo -e "   Branch-relation?:$ePF $(git -C $ArduionoCOMPS branch --contains 2ba3ed3) $eNO"
	git -C "$ArduionoCOMPS" checkout "$AR_COMMIT" --quiet
fi
if [ "$AR_BRANCH" ]; then
	echo -e "...Checkout BRANCH:$eTG '$AR_BRANCH'$eNO"
	git -C "$ArduionoCOMPS" checkout "$AR_BRANCH" --quiet
fi
#--------------------------------------------------------
# Get additional infos
#--------------------------------------------------------
if [ -z $AR_BRANCH ]; then
	# Set HEAD_REF if not already set 
	if [ -z $GITHUB_HEAD_REF ]; then
		current_branch=`git branch --show-current --quiet`
	else
		current_branch="$GITHUB_HEAD_REF"
	fi
	echo -e "   Current Branch:$eTG $current_branch $eNO"
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
# $?: Status of the last executed command => 0:OK, 1:Error 
if [ $? -ne 0 ]; then exit 1; fi
#--------------------------------------------------------
# Get esp32-arduino-libs COMPONENT
#--------------------------------------------------------
if [ ! -d "$IDF_LIBS_DIR" ]; then
	echo -e "...Cloning esp32-arduino-libs...$eGI$AR_LIBS_REPO_URL$eNO"
	echo -e "   to: $(shortFP $IDF_LIBS_DIR)"   
	git clone "$AR_LIBS_REPO_URL" "$IDF_LIBS_DIR" --quiet
else
	echo -e "...Updating existing esp32-arduino-libs...$eGI$AR_LIBS_REPO_URL$eNO"
	echo -e "   in: $(shortFP $(realpath $IDF_LIBS_DIR))"
	git -C "$IDF_LIBS_DIR" fetch --quiet && \
	git -C "$IDF_LIBS_DIR" pull --quiet --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi