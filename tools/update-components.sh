#/bin/bash

source ./tools/config.sh

CAMERA_REPO_URL="https://github.com/espressif/esp32-camera.git"
FACE_REPO_URL="https://github.com/espressif/esp-dl.git"
RMAKER_REPO_URL="https://github.com/espressif/esp-rainmaker.git"
DSP_REPO_URL="https://github.com/espressif/esp-dsp.git"
LITTLEFS_REPO_URL="https://github.com/joltwallet/esp_littlefs.git"
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"

#
# CLONE/UPDATE ARDUINO
#

if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

if [ -z $AR_BRANCH ]; then
	has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "idf-$IDF_BRANCH"`
	if [ "$has_ar_branch" == "1" ]; then
		export AR_BRANCH="idf-$IDF_BRANCH"
	else
		has_ar_branch=`git_branch_exists "$AR_COMPS/arduino" "$AR_PR_TARGET_BRANCH"`
		if [ "$has_ar_branch" == "1" ]; then
			export AR_BRANCH="$AR_PR_TARGET_BRANCH"
		fi
	fi
fi

if [ "$AR_BRANCH" ]; then
	git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH"
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP32-CAMERA
#

if [ ! -d "$AR_COMPS/esp32-camera" ]; then
	git clone $CAMERA_REPO_URL "$AR_COMPS/esp32-camera"
else
	git -C "$AR_COMPS/esp32-camera" fetch && \
	git -C "$AR_COMPS/esp32-camera" pull --ff-only
fi
#this is a temp measure to fix build issue in recent IDF master
if [ -f "$AR_COMPS/esp32-camera/idf_component.yml" ]; then
	rm -rf "$AR_COMPS/esp32-camera/idf_component.yml"
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-FACE
#

if [ ! -d "$AR_COMPS/esp-face" ]; then
	git clone $FACE_REPO_URL "$AR_COMPS/esp-face"
	# cml=`cat "$AR_COMPS/esp-face/CMakeLists.txt"`
	# echo "if(IDF_TARGET STREQUAL \"esp32\" OR IDF_TARGET STREQUAL \"esp32s2\" OR IDF_TARGET STREQUAL \"esp32s3\")" > "$AR_COMPS/esp-face/CMakeLists.txt"
	# echo "$cml" >> "$AR_COMPS/esp-face/CMakeLists.txt"
	# echo "endif()" >> "$AR_COMPS/esp-face/CMakeLists.txt"
else
	git -C "$AR_COMPS/esp-face" fetch && \
	git -C "$AR_COMPS/esp-face" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-LITTLEFS
#

if [ ! -d "$AR_COMPS/esp_littlefs" ]; then
	git clone $LITTLEFS_REPO_URL "$AR_COMPS/esp_littlefs" && \
    git -C "$AR_COMPS/esp_littlefs" submodule update --init --recursive
else
	git -C "$AR_COMPS/esp_littlefs" fetch && \
	git -C "$AR_COMPS/esp_littlefs" pull --ff-only && \
    git -C "$AR_COMPS/esp_littlefs" submodule update --init --recursive
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-RAINMAKER
#

if [ ! -d "$AR_COMPS/esp-rainmaker" ]; then
    git clone $RMAKER_REPO_URL "$AR_COMPS/esp-rainmaker"
    git -C "$AR_COMPS/esp-rainmaker" checkout f1b82c71c4536ab816d17df016d8afe106bd60e3
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-DSP
#

if [ ! -d "$AR_COMPS/esp-dsp" ]; then
	git clone $DSP_REPO_URL "$AR_COMPS/esp-dsp"
	cml=`cat "$AR_COMPS/esp-dsp/CMakeLists.txt"`
	echo "if(IDF_TARGET STREQUAL \"esp32\" OR IDF_TARGET STREQUAL \"esp32s2\" OR IDF_TARGET STREQUAL \"esp32s3\")" > "$AR_COMPS/esp-dsp/CMakeLists.txt"
	echo "$cml" >> "$AR_COMPS/esp-dsp/CMakeLists.txt"
	echo "endif()" >> "$AR_COMPS/esp-dsp/CMakeLists.txt"
else
	git -C "$AR_COMPS/esp-dsp" fetch && \
	git -C "$AR_COMPS/esp-dsp" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE TINYUSB
#

if [ ! -d "$AR_COMPS/arduino_tinyusb/tinyusb" ]; then
	git clone $TINYUSB_REPO_URL "$AR_COMPS/arduino_tinyusb/tinyusb"
else
	git -C "$AR_COMPS/arduino_tinyusb/tinyusb" fetch && \
	git -C "$AR_COMPS/arduino_tinyusb/tinyusb" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

