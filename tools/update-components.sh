#!/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#
if [ -z $ARDUINO_BRANCH ]; then
	has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "idf-$IDF_BRANCH"`
	if [ "$has_ar_branch" == "1" ]; then
		ARDUINO_BRANCH="idf-$IDF_BRANCH"
	else
		has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "$AR_PR_TARGET_BRANCH"`
		if [ "$has_ar_branch" == "1" ]; then
			ARDUINO_BRANCH="$AR_PR_TARGET_BRANCH"
		else
			ARDUINO_BRANCH="master"
		fi
	fi
fi

if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino" -b $ARDUINO_BRANCH
else
	git -C "$AR_COMPS/arduino" checkout $ARDUINO_BRANCH && \
	git -C "$AR_COMPS/arduino" fetch origin && \
	git -C "$AR_COMPS/arduino" pull origin $ARDUINO_BRANCH
fi
if [ $? -ne 0 ]; then exit 1; fi
git -C "$AR_COMPS/arduino" submodule update --init --recursive

#
# CLONE/UPDATE ESP32-CAMERA
#

if [ ! -d "$AR_COMPS/esp32-camera" ]; then
	git clone $CAMERA_REPO_URL "$AR_COMPS/esp32-camera"
else
	git -C "$AR_COMPS/esp32-camera" fetch origin && \
	git -C "$AR_COMPS/esp32-camera" pull origin master
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-FACE
#

if [ ! -d "$AR_COMPS/esp-face" ]; then
	git clone $FACE_REPO_URL "$AR_COMPS/esp-face"
else
	git -C "$AR_COMPS/esp-face" fetch origin && \
	git -C "$AR_COMPS/esp-face" pull origin master
fi
if [ $? -ne 0 ]; then exit 1; fi
