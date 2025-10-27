#!/bin/bash

if ! [ -x "$(command -v python3)" ]; then
    echo "ERROR: python is not installed or not in PATH! Please install python first."
    exit 1
fi

if ! [ -x "$(command -v git)" ]; then
    echo "ERROR: git is not installed or not in PATH! Please install git first."
    exit 1
fi

if ! [ -x "$(command -v ninja)" ]; then
    echo "ERROR: ninja is not installed or not in PATH! Please install ninja first."
    exit 1
fi

# Fixes building some components. See https://github.com/espressif/arduino-esp32/issues/10167
export IDF_COMPONENT_OVERWRITE_MANAGED_COMPONENTS=1

CCACHE_ENABLE=1

TARGET="all"
BUILD_TYPE="all"
BUILD_DEBUG="default"
SKIP_ENV=0
COPY_OUT=0
ARCHIVE_OUT=0
if [ -z $DEPLOY_OUT ]; then
    DEPLOY_OUT=0
fi

function print_help() {
    echo "Usage: build.sh [-s] [-n] [-A <arduino_branch>] [-I <idf_branch>] [-D <debug_level>] [-i <idf_commit>] [-c <path>] [-t <target>] [-b <build|menuconfig|reconfigure|idf-libs|copy-bootloader|mem-variant|hosted>] [config ...]"
    echo "       -s     Skip installing/updating of ESP-IDF and all components"
    echo "       -n     Disable ccache"
    echo "       -A     Set which branch of arduino-esp32 to be used for compilation"
    echo "       -I     Set which branch of ESP-IDF to be used for compilation"
    echo "       -i     Set which commit of ESP-IDF to be used for compilation"
    echo "       -e     Archive the build to dist"
    echo "       -d     Deploy the build to github arduino-esp32"
    echo "       -D     Debug level to be set to ESP-IDF. One of default,none,error,warning,info,debug or verbose"
    echo "       -c     Set the arduino-esp32 folder to copy the result to. ex. '$HOME/Arduino/hardware/espressif/esp32'"
    echo "       -t     Set the build target(chip) ex. 'esp32s3' or select multiple targets(chips) by separating them with comma ex. 'esp32,esp32s3,esp32c3'"
    echo "       -b     Set the build type. ex. 'build' to build the project and prepare for uploading to a board"
    echo "       ...    Specify additional configs to be applied. ex. 'qio 80m' to compile for QIO Flash@80MHz. Requires -b"
    exit 1
}

while getopts ":A:I:i:c:t:b:D:sde" opt; do
    case ${opt} in
        s )
            SKIP_ENV=1
            ;;
        n )
            CCACHE_ENABLE=0
            ;;
        d )
            DEPLOY_OUT=1
            ;;
        e )
            ARCHIVE_OUT=1
            ;;
        c )
            export ESP32_ARDUINO="$OPTARG"
            COPY_OUT=1
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
        D )
            BUILD_DEBUG="$OPTARG"
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
               [ "$b" != "mem-variant" ] && 
               [ "$b" != "hosted" ]; then
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

export IDF_CCACHE_ENABLE=$CCACHE_ENABLE

# Output the TARGET array
echo "TARGET(s): ${TARGET[@]}"

mkdir -p dist

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

if [ "$BUILD_TYPE" != "all" ]; then
    if [ "$TARGET" = "all" ]; then
        echo "ERROR: You need to specify target for non-default builds"
        print_help
    fi

    if [ "$BUILD_TYPE" == "hosted" ]; then
        ./tools/build-hosted.sh
        exit $?
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

        configs="configs/defconfig.common;configs/defconfig.$target;configs/defconfig.debug_$BUILD_DEBUG"
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

rm -rf build sdkconfig out
mkdir -p "$AR_TOOLS/esp32-arduino-libs"

#targets_count=`jq -c '.targets[] | length' configs/builds.json`
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

    # Build Main Configs List
    main_configs="configs/defconfig.common;configs/defconfig.$target;configs/defconfig.debug_$BUILD_DEBUG"
    for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
        main_configs="$main_configs;configs/defconfig.$defconf"
    done

    # Build IDF Libs
    idf_libs_configs="$main_configs"
    for defconf in `echo "$target_json" | jq -c '.idf_libs[]' | tr -d '"'`; do
        idf_libs_configs="$idf_libs_configs;configs/defconfig.$defconf"
    done

    echo "* Build IDF-Libs: $idf_libs_configs"
    rm -rf build sdkconfig
    idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" idf-libs
    if [ $? -ne 0 ]; then exit 1; fi

    # Build ESP-Hosted slave firmwares
    if [ "$target" == "esp32p4" ]; then
        ./tools/build-hosted.sh
    fi

    # Build ESP-SR Models
    if [ "$target" == "esp32s3" ] || [ "$target" == "esp32p4" ]; then
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" srmodels_bin
        if [ $? -ne 0 ]; then exit 1; fi
        AR_SDK="$AR_TOOLS/esp32-arduino-libs/$target"
        # sr model.bin
        if [ -f "build/srmodels/srmodels.bin" ]; then
            echo "$AR_SDK/esp_sr"
            mkdir -p "$AR_SDK/esp_sr"
            cp -f "build/srmodels/srmodels.bin" "$AR_SDK/esp_sr/"
            cp -f "partitions.csv" "$AR_SDK/esp_sr/"
        fi
    fi

    # Build Bootloaders
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

    # Build Memory Variants
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

#
# Add components version info
#
rm -rf "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# The lib-builder version
component_version="lib-builder: "$(git -C "$AR_ROOT" symbolic-ref --short HEAD || git -C "$AR_ROOT" tag --points-at HEAD)" "$(git -C "$AR_ROOT" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# ESP-IDF version
component_version="esp-idf: "$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)" "$(git -C "$IDF_PATH" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# components version
for component in `ls "$AR_COMPS"`; do
    if [ -d "$AR_COMPS/$component/.git" ]; then
        component_version="$component: "$(git -C "$AR_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done
# TinyUSB version
component_version="tinyusb: "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" symbolic-ref --short HEAD || git -C "$AR_COMPS/arduino_tinyusb/tinyusb" tag --points-at HEAD)" "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# managed components version
for component in `ls "$AR_MANAGED_COMPS"`; do
    if [ -d "$AR_MANAGED_COMPS/$component/.git" ]; then
        component_version="$component: "$(git -C "$AR_MANAGED_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_MANAGED_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_MANAGED_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    elif [ -f "$AR_MANAGED_COMPS/$component/idf_component.yml" ]; then
        component_version="$component: "$(cat "$AR_MANAGED_COMPS/$component/idf_component.yml" | grep "^version: " | cut -d ' ' -f 2)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done

# update package_esp32_index.template.json
if [ "$BUILD_TYPE" = "all" ]; then
    echo "* Generating package_esp32_index.template.json..."
    python3 ./tools/gen_tools_json.py -i "$IDF_PATH" -j "$AR_COMPS/arduino/package/package_esp32_index.template.json" -o "$AR_OUT/"
    python3 ./tools/gen_tools_json.py -i "$IDF_PATH" -o "$TOOLS_JSON_OUT/"
    if [ $? -ne 0 ]; then exit 1; fi
fi

# Generate pioarduino manifest file
if [ "$BUILD_TYPE" = "all" ]; then
    echo "* Generating pioarduino manifest file..."
    pushd $IDF_PATH
    ibr=$(git describe --all 2>/dev/null)
    ic=$(git -C "$IDF_PATH" rev-parse --short HEAD)
    popd
    python3 ./tools/gen_pioarduino_manifest.py -o "$TOOLS_JSON_OUT/" -s "$ibr" -c "$ic"
    if [ $? -ne 0 ]; then exit 1; fi
fi

# copy everything to arduino-esp32 installation
if [ $COPY_OUT -eq 1 ] && [ -d "$ESP32_ARDUINO" ]; then
    echo "* Copying to Arduino..."
    ./tools/copy-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi

# push changes to esp32-arduino-libs and create pull request into arduino-esp32
if [ $DEPLOY_OUT -eq 1 ]; then
    echo "* Pushing to Arduino..."
    ./tools/push-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi

# archive the build
if [ $ARCHIVE_OUT -eq 1 ]; then
    echo "* Archiving build..."
    ./tools/archive-build.sh "$TARGET"
    if [ $? -ne 0 ]; then exit 1; fi
fi
