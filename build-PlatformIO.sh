#!/bin/bash

if ! [ -x "$(command -v python3)" ]; then
    echo "ERROR: python is not installed! Please install python first."
    exit 1
fi

if ! [ -x "$(command -v git)" ]; then
    echo "ERROR: git is not installed! Please install git first."
    exit 1
fi

export TARGET="all"
BUILD_TYPE="all"
SKIP_ENV=0
COPY_OUT=0
ARCHIVE_OUT=1
DEPLOY_OUT=0
#-------------------------------------
#  Function to print the help message
#-------------------------------------
function print_help() {
    echo "Usage: build.sh [-s] [-A <arduino_branch>] [-I <idf_branch>] [-i <idf_commit>] [-c <path>] [-t <target>] [-b <build|menuconfig|reconfigure|idf-libs|copy-bootloader|mem-variant>] [config ...]"
    echo "       -s     Skip installing/updating of ESP-IDF and all components"
    echo "       -A     Set which branch of arduino-esp32 to be used for compilation"
    echo "       -I     Set which branch of ESP-IDF to be used for compilation"
    echo "       -i     Set which commit of ESP-IDF to be used for compilation"
    echo "       -e     Archive the build to dist"
    echo "       -t     Set the build target(chip) ex. 'esp32s3' or select multiple targets(chips) by separating them with comma ex. 'esp32,esp32s3,esp32c3'"
    echo "       -b     Set the build type. ex. 'build' to build the project and prepare for uploading to a board"
    echo "       ...    Specify additional configs to be applied. ex. 'qio 80m' to compile for QIO Flash@80MHz. Requires -b"
    exit 1
}
#-------------------------------
# Process Arguments were passed
#-------------------------------
while getopts ":A:I:i:c:t:b:sde" opt; do
    case ${opt} in
        s )
            SKIP_ENV=1
            ;;
        e )
            ARCHIVE_OUT=1
            ;;
        A )
            export AR_BRANCH="$OPTARG"
            ;;
        I )
            export IDF_BRANCH="$OPTARG"
            ;;
        i )
            export IDF_COMMIT="$OPTARG"
            ;;
        t )
            IFS=',' read -ra TARGET <<< "$OPTARG"
            ;;
        b )
            b=$OPTARG
            if [ "$b" != "build" ] &&
               [ "$b" != "menuconfig" ] &&
               [ "$b" != "reconfigure" ] &&
               [ "$b" != "idf-libs" ] &&
               [ "$b" != "copy-bootloader" ] &&
               [ "$b" != "mem-variant" ]; then
                print_help
            fi
            BUILD_TYPE="$b"
            ;;
        \? )
            echo "Invalid option: -$OPTARG" 1>&2
            print_help
            ;;
        : )
            echo "Invalid option: -$OPTARG requires an argument" 1>&2
            print_help
            ;;
    esac
done
shift $((OPTIND -1))
CONFIGS=$@

# Output the TARGET array
echo "TARGET(s): ${TARGET[@]}"

mkdir -p dist
rm -rf dependencies.lock
# **********************************************
# ******     LOAD needed Components      *******
# **********************************************
if [ $SKIP_ENV -eq 0 ]; then
    echo "* Installing/Updating ESP-IDF and all components..."
    # update components from git
    ./tools/update-components.sh
    if [ $? -ne 0 ]; then exit 1; fi

    # install arduino component
    ./tools/install-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi

    # install esp-idf
    source ./tools/install-esp-idf.sh
    if [ $? -ne 0 ]; then exit 1; fi
else
    # $IDF_PATH/install.sh
    # source $IDF_PATH/export.sh
    source ./tools/config.sh
fi
# **********************************************
# *****   Build II ALL   ******
# **********************************************
if [ "$BUILD_TYPE" != "all" ]; then
    if [ "$TARGET" = "all" ]; then
        echo "ERROR: You need to specify target for non-default builds"
        print_help
    fi

    # Target Features Configs
    for target_json in `jq -c '.targets[]' configs/builds.json`; do
        target=$(echo "$target_json" | jq -c '.target' | tr -d '"')

        # Check if $target is in the $TARGET array
        target_in_array=false
        for item in "${TARGET[@]}"; do
            if [ "$item" = "$target" ]; then
                target_in_array=true
                break
            fi
        done

        if [ "$target_in_array" = false ]; then
            # Skip building for targets that are not in the $TARGET array
            continue
        fi

        configs="configs/defconfig.common;configs/defconfig.$target"
        for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
            configs="$configs;configs/defconfig.$defconf"
        done

        echo "* Building for $target"

        # Configs From Arguments
        for conf in $CONFIGS; do
            configs="$configs;configs/defconfig.$conf"
        done

        echo "idf.py -DIDF_TARGET=\"$target\" -DSDKCONFIG_DEFAULTS=\"$configs\" $BUILD_TYPE"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$configs" $BUILD_TYPE
        if [ $? -ne 0 ]; then exit 1; fi
    done
    exit 0
fi
# **********************************************
# ******     BUILD the Components        *******
# **********************************************
rm -rf build sdkconfig out
mkdir -p "$AR_TOOLS/esp32-arduino-libs"

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# NEW NEW NEW NEW NEW NEW NEW NEW NEW  NEW NEW NEW NEW
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Add release-info
rm -rf release-info.txt
IDF_Commit_short=$(git -C "$IDF_PATH" rev-parse --short HEAD || echo "")
AR_Commit_short=$(git -C "$AR_COMPS/arduino" rev-parse --short HEAD || echo "")
echo "Framework built from
- $IDF_REPO branch [$IDF_BRANCH](https://github.com/$IDF_REPO/tree/$IDF_BRANCH) commit [$IDF_Commit_short](https://github.com/$IDF_REPO/commits/$IDF_BRANCH/#:~:text=$IDF_Commit_short)
- $AR_REPO branch [$AR_BRANCH](https://github.com/$AR_REPO/tree/$AR_BRANCH) commit [$AR_Commit_short](https://github.com/$AR_REPO/commits/$AR_BRANCH/#:~:text=$AR_Commit_short)
- Arduino lib builder branch: $GIT_BRANCH" >> release-info.txt
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#-------------------------
# Loop over given Targets
#-------------------------
for target_json in `jq -c '.targets[]' configs/builds.json`; do
    target=$(echo "$target_json" | jq -c '.target' | tr -d '"')
    target_skip=$(echo "$target_json" | jq -c '.skip // 0')

    # Check if $target is in the $TARGET array if not "all"
    if [ "$TARGET" != "all" ]; then
        target_in_array=false
        for item in "${TARGET[@]}"; do
            if [ "$item" = "$target" ]; then
                target_in_array=true
                break
            fi
        done

        # If $target is not in the $TARGET array, skip processing
        if [ "$target_in_array" = false ]; then
            echo "* Skipping Target: $target"
            continue
        fi
    fi

    # Skip chips that should not be a part of the final libs
    # WARNING!!! this logic needs to be updated when cron builds are split into jobs
    if [ "$TARGET" = "all" ] && [ $target_skip -eq 1 ]; then
        echo "* Skipping Target: $target"
        continue
    fi

    echo "* Target: $target"

    #-------------------------
    # Build Main Configs List
    #-------------------------
    main_configs="configs/defconfig.common;configs/defconfig.$target"
    for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
        main_configs="$main_configs;configs/defconfig.$defconf"
    done
    #---------------------
    # Build IDF Libs List
    #---------------------
    idf_libs_configs="$main_configs"
    for defconf in `echo "$target_json" | jq -c '.idf_libs[]' | tr -d '"'`; do
        idf_libs_configs="$idf_libs_configs;configs/defconfig.$defconf"
    done
    #----------------
    # Build IDF Libs
    #----------------
    echo "* Build IDF-Libs: $idf_libs_configs"
    rm -rf build sdkconfig
    idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" idf-libs
    if [ $? -ne 0 ]; then exit 1; fi

    #-------------------
    # Build Bootloaders
    #-------------------
    for boot_conf in `echo "$target_json" | jq -c '.bootloaders[]'`; do
        bootloader_configs="$main_configs"
        for defconf in `echo "$boot_conf" | jq -c '.[]' | tr -d '"'`; do
            bootloader_configs="$bootloader_configs;configs/defconfig.$defconf";
        done

        echo "* Build BootLoader: $bootloader_configs"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$bootloader_configs" copy-bootloader
        if [ $? -ne 0 ]; then exit 1; fi
    done

    #-----------------------
    # Build Memory Variants
    #-----------------------
    for mem_conf in `echo "$target_json" | jq -c '.mem_variants[]'`; do
        mem_configs="$main_configs"
        for defconf in `echo "$mem_conf" | jq -c '.[]' | tr -d '"'`; do
            mem_configs="$mem_configs;configs/defconfig.$defconf";
        done

        echo "* Build Memory Variant: $mem_configs"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$mem_configs" mem-variant
        if [ $? -ne 0 ]; then exit 1; fi
    done
done
# **********************************************
# ******  Add components version info    *******
# **********************************************
################################
# Create NEW Version Info-File
################################
rm -rf "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write lib-builder version
# -------------------------
component_version="lib-builder: "$(git -C "$AR_ROOT" symbolic-ref --short HEAD || git -C "$AR_ROOT" tag --points-at HEAD)" "$(git -C "$AR_ROOT" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write ESP-IDF version
# -------------------------
component_version="esp-idf: "$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)" "$(git -C "$IDF_PATH" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write components version
# -------------------------
for component in `ls "$AR_COMPS"`; do
    if [ -d "$AR_COMPS/$component/.git" ]; then
        component_version="$component: "$(git -C "$AR_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done
# -------------------------
# Write TinyUSB version
# -------------------------
component_version="tinyusb: "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" symbolic-ref --short HEAD || git -C "$AR_COMPS/arduino_tinyusb/tinyusb" tag --points-at HEAD)" "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write managed components version
# -------------------------
for component in `ls "$AR_MANAGED_COMPS"`; do
    if [ -d "$AR_MANAGED_COMPS/$component/.git" ]; then
        component_version="$component: "$(git -C "$AR_MANAGED_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_MANAGED_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_MANAGED_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    elif [ -f "$AR_MANAGED_COMPS/$component/idf_component.yml" ]; then
        component_version="$component: "$(cat "$AR_MANAGED_COMPS/$component/idf_component.yml" | grep "^version: " | cut -d ' ' -f 2)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# NEW NEW NEW NEW NEW NEW NEW NEW NEW  NEW NEW NEW NEW
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ###################################
# Generate PlatformIO manifest file
# ###################################
if [ "$BUILD_TYPE" = "all" ]; then
    python3 ./tools/gen_pio_lib_manifest.py -o "$TOOLS_JSON_OUT/" -s "v$IDF_VERSION" -c "$IDF_COMMIT"
    if [ $? -ne 0 ]; then exit 1; fi
fi

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# NEW NEW NEW NEW NEW NEW NEW NEW NEW  NEW NEW NEW NEW
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
AR_VERSION=$(jq -c '.version' "$AR_COMPS/arduino/package.json" | tr -d '"')
AR_VERSION_UNDERSCORE=`echo "$AR_VERSION" | tr . _`
# Generate PlatformIO framework manifest file
rm -rf "$AR_ROOT/package.json"
if [ "$BUILD_TYPE" = "all" ]; then
    python3 ./tools/gen_pio_frmwk_manifest.py -o "$AR_ROOT/" -s "v$AR_VERSION" -c "$IDF_COMMIT"
    if [ $? -ne 0 ]; then exit 1; fi
fi

# Generate core_version.h
rm -rf "$AR_ROOT/core_version.h"
echo "#define ARDUINO_ESP32_GIT_VER 0x$AR_Commit_short
#define ARDUINO_ESP32_GIT_DESC $AR_VERSION
#define ARDUINO_ESP32_RELEASE_$AR_VERSION_UNDERSCORE
#define ARDUINO_ESP32_RELEASE \"$AR_VERSION_UNDERSCORE\"" >> "$AR_ROOT/core_version.h"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ##############################################
# Write archive with the build stuff
# ##############################################
if [ $ARCHIVE_OUT -eq 1 ]; then
    ./tools/archive-build.sh "$TARGET"
    if [ $? -ne 0 ]; then exit 1; fi
fi
