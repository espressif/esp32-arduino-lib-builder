#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
echo     "...Component ESP32 Arduino installing/updating local copy...."
if [ ! -d "$AR_COMPS/arduino" ]; then
	echo -e "   cloning $eGI$AR_REPO_URL$eNO\n   to:$ePF $AR_COMPS/arduino$eNO"
	git clone $AR_REPO_URL "$AR_COMPS/arduino" --quiet
fi

if [ -z $AR_BRANCH ]; then
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

if [ "$AR_BRANCH" ]; then
	echo "...Checkout BRANCH:'$AR_BRANCH'"
	git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH" --quiet && \
	git -C "$AR_COMPS/arduino" fetch --quiet && \
	git -C "$AR_COMPS/arduino" pull --quiet --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP32-ARDUINO-LIBS
#
if [ ! -d "$IDF_LIBS_DIR" ]; then
	echo -e "...Cloning esp32-arduino-libs...$eGI$AR_LIBS_REPO_URL$eNO"
	echo -e "   to:$ePF $IDF_LIBS_DIR $eNo"
	git clone "$AR_LIBS_REPO_URL" "$IDF_LIBS_DIR" --quiet
else
	echo    "...Updating esp32-arduino-libs..."
	echo -e "   in:$ePF $IDF_LIBS_DIR $eNO"
	git -C "$IDF_LIBS_DIR" fetch --quiet && \
	git -C "$IDF_LIBS_DIR" pull --quiet --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

