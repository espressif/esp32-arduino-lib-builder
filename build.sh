#!/bin/bash

if ! [ -x "$(command -v python3)" ]; then
    echo "ERROR: python is not installed! Please install python first."
    exit 1
fi

if ! [ -x "$(command -v git)" ]; then
    echo "ERROR: git is not installed! Please install git first."
    exit 1
fi

TARGET="all"
BUILD_TYPE="all"
SKIP_ENV=0
COPY_OUT=0
ARCHIVE_OUT=0
if [ -z $DEPLOY_OUT ]; then
    DEPLOY_OUT=0
fi

function print_help() {
    echo "Usage: build.sh [-s] [-A <arduino_branch>] [-I <idf_branch>] [-i <idf_commit>] [-c <path>] [-t <target>] [-b <build|menuconfig|reconfigure|idf_libs|copy_bootloader|mem_variant>] [config ...]"
    echo "       -s     Skip installing/updating of ESP-IDF and all components"
    echo "       -A     Set which branch of arduino-esp32 to be used for compilation"
    echo "       -I     Set which branch of ESP-IDF to be used for compilation"
    echo "       -i     Set which commit of ESP-IDF to be used for compilation"
    echo "       -e     Archive the build to dist"
    echo "       -d     Deploy the build to github arduino-esp32"
    echo "       -c     Set the arduino-esp32 folder to copy the result to. ex. '$HOME/Arduino/hardware/espressif/esp32'"
    echo "       -t     Set the build target(chip). ex. 'esp32s3'"
    echo "       -b     Set the build type. ex. 'build' to build the project and prepare for uploading to a board"
    echo "       ...    Specify additional configs to be applied. ex. 'qio 80m' to compile for QIO Flash@80MHz. Requires -b"
    exit 1
}

while getopts ":A:I:i:c:t:b:sde" opt; do
    case ${opt} in
        s )
            SKIP_ENV=1
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
        t )
            TARGET=$OPTARG
            ;;
        b )
            b=$OPTARG
            if [ "$b" != "build" ] && 
               [ "$b" != "menuconfig" ] && 
               [ "$b" != "reconfigure" ] && 
               [ "$b" != "idf_libs" ] && 
               [ "$b" != "copy_bootloader" ] && 
               [ "$b" != "mem_variant" ]; then
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

if [ -f "./managed_components/espressif__esp-sr/.component_hash" ]; then
    rm -rf ./managed_components/espressif__esp-sr/.component_hash
fi

if [ "$BUILD_TYPE" != "all" ]; then
    if [ "$TARGET" = "all" ]; then
        echo "ERROR: You need to specify target for non-default builds"
        print_help
    fi
    configs="configs/defconfig.common;configs/defconfig.$TARGET"
    
    # Target Features Configs
    for target_json in `jq -c '.targets[]' configs/builds.json`; do
        target=$(echo "$target_json" | jq -c '.target' | tr -d '"')
        if [ "$TARGET" == "$target" ]; then
            for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
                configs="$configs;configs/defconfig.$defconf"
            done
        fi
    done

    # Configs From Arguments
    for conf in $CONFIGS; do
        configs="$configs;configs/defconfig.$conf"
    done

    echo "idf.py -DIDF_TARGET=\"$TARGET\" -DSDKCONFIG_DEFAULTS=\"$configs\" $BUILD_TYPE"
    rm -rf build sdkconfig
    idf.py -DIDF_TARGET="$TARGET" -DSDKCONFIG_DEFAULTS="$configs" $BUILD_TYPE
    if [ $? -ne 0 ]; then exit 1; fi
    exit 0
fi

rm -rf build sdkconfig out

# Add components version info
mkdir -p "$AR_TOOLS/esp32-arduino-libs" && rm -rf version.txt && rm -rf "$AR_TOOLS/esp32-arduino-libs/versions.txt"
component_version="esp-idf: "$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)" "$(git -C "$IDF_PATH" rev-parse --short HEAD)
echo $component_version >> version.txt && echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
for component in `ls "$AR_COMPS"`; do
    if [ -d "$AR_COMPS/$component/.git" ] || [ -d "$AR_COMPS/$component/.github" ]; then
        component_version="$component: "$(git -C "$AR_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> version.txt && echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done
component_version="tinyusb: "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" symbolic-ref --short HEAD || git -C "$AR_COMPS/arduino_tinyusb/tinyusb" tag --points-at HEAD)" "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" rev-parse --short HEAD)
echo $component_version >> version.txt && echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"

#targets_count=`jq -c '.targets[] | length' configs/builds.json`
for target_json in `jq -c '.targets[]' configs/builds.json`; do
    target=$(echo "$target_json" | jq -c '.target' | tr -d '"')

    if [ "$TARGET" != "all" ] && [ "$TARGET" != "$target" ]; then
        echo "* Skipping Target: $target"
        continue
    fi

    echo "* Target: $target"

    # Build Main Configs List
    main_configs="configs/defconfig.common;configs/defconfig.$target"
    for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
        main_configs="$main_configs;configs/defconfig.$defconf"
    done

    # Build IDF Libs
    idf_libs_configs="$main_configs"
    for defconf in `echo "$target_json" | jq -c '.idf_libs[]' | tr -d '"'`; do
        idf_libs_configs="$idf_libs_configs;configs/defconfig.$defconf"
    done

    if [ -f "./managed_components/espressif__esp-sr/.component_hash" ]; then
        rm -rf ./managed_components/espressif__esp-sr/.component_hash
    fi

    echo "* Build IDF-Libs: $idf_libs_configs"
    rm -rf build sdkconfig
    idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" idf_libs
    if [ $? -ne 0 ]; then exit 1; fi

    # Build Bootloaders
    for boot_conf in `echo "$target_json" | jq -c '.bootloaders[]'`; do
        bootloader_configs="$main_configs"
        for defconf in `echo "$boot_conf" | jq -c '.[]' | tr -d '"'`; do
            bootloader_configs="$bootloader_configs;configs/defconfig.$defconf";
        done

        if [ -f "./managed_components/espressif__esp-sr/.component_hash" ]; then
            rm -rf ./managed_components/espressif__esp-sr/.component_hash
        fi

        echo "* Build BootLoader: $bootloader_configs"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$bootloader_configs" copy_bootloader
        if [ $? -ne 0 ]; then exit 1; fi
    done

    # Build Memory Variants
    for mem_conf in `echo "$target_json" | jq -c '.mem_variants[]'`; do
        mem_configs="$main_configs"
        for defconf in `echo "$mem_conf" | jq -c '.[]' | tr -d '"'`; do
            mem_configs="$mem_configs;configs/defconfig.$defconf";
        done

        if [ -f "./managed_components/espressif__esp-sr/.component_hash" ]; then
            rm -rf ./managed_components/espressif__esp-sr/.component_hash
        fi

        echo "* Build Memory Variant: $mem_configs"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$mem_configs" mem_variant
        if [ $? -ne 0 ]; then exit 1; fi
    done
done

# update package_esp32_index.template.json
if [ "$BUILD_TYPE" = "all" ]; then
    python3 ./tools/gen_tools_json.py -i "$IDF_PATH" -j "$AR_COMPS/arduino/package/package_esp32_index.template.json" -o "$AR_OUT/"
    python3 ./tools/gen_tools_json.py -i "$IDF_PATH" -o "$TOOLS_JSON_OUT/"
    if [ $? -ne 0 ]; then exit 1; fi
fi

# Generate PlatformIO manifest file
if [ "$BUILD_TYPE" = "all" ]; then
    python3 ./tools/gen_platformio_manifest.py -o "$TOOLS_JSON_OUT/" -s $(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD) -c $(git -C "$IDF_PATH" rev-parse --short HEAD)
    if [ $? -ne 0 ]; then exit 1; fi
fi

# copy everything to arduino-esp32 installation
if [ $COPY_OUT -eq 1 ] && [ -d "$ESP32_ARDUINO" ]; then
    ./tools/copy-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi

# push changes to esp32-arduino-libs and create pull request into arduino-esp32
if [ $DEPLOY_OUT -eq 1 ]; then
    ./tools/push-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi

# archive the build
if [ $ARCHIVE_OUT -eq 1 ]; then
    ./tools/archive-build.sh "$TARGET"
    if [ $? -ne 0 ]; then exit 1; fi
fi
