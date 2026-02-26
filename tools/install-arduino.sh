#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
echo "Updating ESP32 Arduino..."
if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

if [ -z $AR_SOURCE_BRANCH ]; then
	if [ -n "$IDF_COMMIT" ]; then
		IDF_REF="$IDF_COMMIT"
	elif [ -n "$IDF_TAG" ]; then
		IDF_REF="$IDF_TAG"
	else
		IDF_REF="$IDF_BRANCH"
	fi
	set_ar_source_branch "git_branch_exists" "$AR_COMPS/arduino" "$IDF_REF"
fi

if [ "$AR_SOURCE_BRANCH" ]; then
	echo "AR_SOURCE_BRANCH='$AR_SOURCE_BRANCH'"
	git -C "$AR_COMPS/arduino" fetch --all && \
	git -C "$AR_COMPS/arduino" checkout -B "$AR_SOURCE_BRANCH" origin/"$AR_SOURCE_BRANCH" && \
	git -C "$AR_COMPS/arduino" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
