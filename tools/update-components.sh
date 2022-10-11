#/bin/bash

set -e

source ./tools/config.sh

CAMERA_REPO_URL="https://github.com/espressif/esp32-camera.git"
DL_REPO_URL="https://github.com/espressif/esp-dl.git"
SR_REPO_URL="https://github.com/espressif/esp-sr.git"
RMAKER_REPO_URL="https://github.com/espressif/esp-rainmaker.git"
DSP_REPO_URL="https://github.com/espressif/esp-dsp.git"
LITTLEFS_REPO_URL="https://github.com/joltwallet/esp_littlefs.git"
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"

if [ -n "$RECREATE" ]; then
	VERSION="./tools/version-$IDF_BRANCH.sh"
	if [ ! -f "$VERSION" ]; then
		echo "$VERSION does not exists"
		exit 1
	fi
	source $VERSION
fi

#
# CLONE/UPDATE ARDUINO
#
if [ -z "AR_REPO_VERSION" ]; then
	if [ ! -d "$AR_COMPS/arduino" ]; then
		git clone $AR_REPO_URL "$AR_COMPS/arduino"
	fi

	if [ -z $AR_BRANCH ]; then
		if [ -z $GITHUB_HEAD_REF ]; then
			current_branch=`git branch --show-current`
		else
			current_branch="$GITHUB_HEAD_REF"
		fi
		echo "Current Branch: $current_branch"
		if [[ "$current_branch" != "master" && `git_branch_exists "$AR_COMPS/arduino" "$current_branch"` == "1" ]]; then
			export AR_BRANCH="$current_branch"
		else
			if [ -z "$IDF_COMMIT" ]; then #commit was not specified at build time
				AR_BRANCH_NAME="idf-$IDF_BRANCH"
			else
				AR_BRANCH_NAME="idf-$IDF_COMMIT"
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
		git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH"
		git -C "$AR_COMPS/arduino" fetch
		git -C "$AR_COMPS/arduino" pull --ff-only
	fi
else
	./tools/git-update.sh "$AR_COMPS/arduino" $AR_REPO_URL $AR_REPO_VERSION
fi

# CLONE/UPDATE ESP32-CAMERA
./tools/git-update.sh "$AR_COMPS/esp32-camera" $CAMERA_REPO_URL $CAMERA_REPO_VERSION

#this is a temp measure to fix build issue in recent IDF master
if [ -f "$AR_COMPS/esp32-camera/idf_component.yml" ]; then
	rm -rf "$AR_COMPS/esp32-camera/idf_component.yml"
fi

# CLONE/UPDATE ESP-DL
./tools/git-update.sh "$AR_COMPS/esp-dl" $DL_REPO_URL $DL_REPO_VERSION

# CLONE/UPDATE ESP-SR
./tools/git-update.sh "$AR_COMPS/esp-sr" $SR_REPO_URL $SR_REPO_VERSION

# CLONE/UPDATE ESP-LITTLEFS
./tools/git-update.sh -s "$AR_COMPS/esp_littlefs" $LITTLEFS_REPO_URL $LITTLEFS_REPO_VERSION

# CLONE/UPDATE ESP-RAINMAKER
./tools/git-update.sh -s "$AR_COMPS/esp-rainmaker" $RMAKER_REPO_URL $RMAKER_REPO_VERSION

# CLONE/UPDATE ESP-DSP
./tools/git-update.sh "$AR_COMPS/esp-dsp" $DSP_REPO_URL $DSP_REPO_VERSION

# CLONE/UPDATE TINYUSB
./tools/git-update.sh "$AR_COMPS/arduino_tinyusb/tinyusb" $TINYUSB_REPO_URL $TINYUSB_REPO_VERSION
