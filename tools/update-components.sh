#/bin/bash

source ./tools/config.sh

CAMERA_REPO_URL="https://github.com/espressif/esp32-camera.git"
DL_REPO_URL="https://github.com/espressif/esp-dl.git"
RMAKER_REPO_URL="https://github.com/espressif/esp-rainmaker.git"
INSIGHTS_REPO_URL="https://github.com/espressif/esp-insights.git"
LITTLEFS_REPO_URL="https://github.com/joltwallet/esp_littlefs.git"
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"

#
# CLONE/UPDATE ARDUINO
#
echo "Updating ESP32 Arduino..."
if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi

if [ -z $AR_BRANCH ] && [ -z $AR_TAG ]; then
	if [ -z $GITHUB_HEAD_REF ]; then
		current_branch=`git branch --show-current`
	else
		current_branch="$GITHUB_HEAD_REF"
	fi
	echo "Current Branch: $current_branch"
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
	echo "AR_BRANCH='$AR_BRANCH'"
	git -C "$AR_COMPS/arduino" checkout "$AR_BRANCH" && \
	git -C "$AR_COMPS/arduino" fetch && \
	git -C "$AR_COMPS/arduino" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

if [ "$AR_TAG" ]; then
  if [ "$AR_BRANCH" ]; then
    echo "Warning: Both branch and tag specifiied for arduino-esp32. Tag takes precedence. Ignoring branch."
  fi
	git -C "$AR_COMPS/arduino" checkout "tags/$AR_TAG" 
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP32-ARDUINO-LIBS
#
if [ ! -d "$IDF_LIBS_DIR" ]; then
	echo "Cloning esp32-arduino-libs..."
	git clone "$IDF_LIBS_REPO_URL" "$IDF_LIBS_DIR"
else
	echo "Updating esp32-arduino-libs..."
	git -C "$IDF_LIBS_DIR" fetch && \
	git -C "$IDF_LIBS_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP32-CAMERA
#
echo "Updating ESP32 Camera..."
if [ ! -d "$AR_COMPS/esp32-camera" ]; then
	git clone $CAMERA_REPO_URL "$AR_COMPS/esp32-camera"
else
	git -C "$AR_COMPS/esp32-camera" fetch && \
	git -C "$AR_COMPS/esp32-camera" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-DL
#
echo "Updating ESP-DL..."
if [ ! -d "$AR_COMPS/esp-dl" ]; then
	git clone $DL_REPO_URL "$AR_COMPS/esp-dl"
	mv "$AR_COMPS/esp-dl/CMakeLists.txt" "$AR_COMPS/esp-dl/CMakeListsOld.txt"
	echo "idf_build_get_property(target IDF_TARGET)" > "$AR_COMPS/esp-dl/CMakeLists.txt"
	echo "if(NOT \${IDF_TARGET} STREQUAL \"esp32c6\" AND NOT \${IDF_TARGET} STREQUAL \"esp32h2\")" >> "$AR_COMPS/esp-dl/CMakeLists.txt"
	cat "$AR_COMPS/esp-dl/CMakeListsOld.txt" >> "$AR_COMPS/esp-dl/CMakeLists.txt"
	echo "endif()" >> "$AR_COMPS/esp-dl/CMakeLists.txt"
else
	git -C "$AR_COMPS/esp-dl" fetch && \
	git -C "$AR_COMPS/esp-dl" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
#this is a temp measure to fix build issue
if [ -f "$AR_COMPS/esp-dl/idf_component.yml" ]; then
	rm -rf "$AR_COMPS/esp-dl/idf_component.yml"
fi

#
# CLONE/UPDATE ESP-SR
#
SR_REPO_URL="https://github.com/espressif/esp-sr.git"
echo "Updating ESP-SR..."
if [ ! -d "$AR_COMPS/esp-sr" ]; then
	git clone $SR_REPO_URL "$AR_COMPS/esp-sr"
	mv "$AR_COMPS/esp-sr/CMakeLists.txt" "$AR_COMPS/esp-sr/CMakeListsOld.txt"
	echo "if(IDF_TARGET STREQUAL \"esp32s3\")" > "$AR_COMPS/esp-sr/CMakeLists.txt"
	cat "$AR_COMPS/esp-sr/CMakeListsOld.txt" >> "$AR_COMPS/esp-sr/CMakeLists.txt"
	echo "endif()" >> "$AR_COMPS/esp-sr/CMakeLists.txt"
	echo "  - esp32c6" >> "$AR_COMPS/esp-sr/idf_component.yml"
	echo "  - esp32h2" >> "$AR_COMPS/esp-sr/idf_component.yml"
else
	git -C "$AR_COMPS/esp-sr" fetch && \
	git -C "$AR_COMPS/esp-sr" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-RAINMAKER
#
echo "Updating ESP-RainMaker..."
if [ ! -d "$AR_COMPS/esp-rainmaker" ]; then
    git clone $RMAKER_REPO_URL "$AR_COMPS/esp-rainmaker" && \
    git -C "$AR_COMPS/esp-rainmaker" submodule update --init --recursive
else
	git -C "$AR_COMPS/esp-rainmaker" fetch && \
	git -C "$AR_COMPS/esp-rainmaker" pull --ff-only && \
    git -C "$AR_COMPS/esp-rainmaker" submodule update --init --recursive
fi
if [ $? -ne 0 ]; then exit 1; fi
if [ -f "$AR_COMPS/esp-rainmaker/components/esp-insights/components/esp_insights/scripts/get_projbuild_gitconfig.py" ] && [ `cat "$AR_COMPS/esp-rainmaker/components/esp-insights/components/esp_insights/scripts/get_projbuild_gitconfig.py" | grep esp32c6 | wc -l` == "0" ]; then
	echo "Overwriting 'get_projbuild_gitconfig.py'"
	cp -f "tools/get_projbuild_gitconfig.py" "$AR_COMPS/esp-rainmaker/components/esp-insights/components/esp_insights/scripts/get_projbuild_gitconfig.py"
fi

#
# CLONE/UPDATE ESP-LITTLEFS
#
echo "Updating ESP-LITTLEFS..."
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
# CLONE/UPDATE TINYUSB
#
echo "Updating TinyUSB..."
if [ ! -d "$AR_COMPS/arduino_tinyusb/tinyusb" ]; then
	git clone $TINYUSB_REPO_URL "$AR_COMPS/arduino_tinyusb/tinyusb"
else
	git -C "$AR_COMPS/arduino_tinyusb/tinyusb" fetch && \
	git -C "$AR_COMPS/arduino_tinyusb/tinyusb" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
