#!/bin/bash

#SKIP_BUILD=1 # Un-comment for: TESTING DEBUGING ONLY 
#------------------------------------------
# Ensure that a alternative bash potentially 
# installed on an the system will be used
#------------------------------------------
# Determine the path to the bash executable
# BASH_PATH=$(which bash)
# # Ensure the bash executable is found
# if [ -z "$BASH_PATH" ]; then
#   echo "bash not found in PATH"
#   exit 1
# fi
# # If the script is not running with the correct bash, re-execute it with the found bash
# if [ "$BASH" != "$BASH_PATH" ]; then
#   exec "$BASH_PATH" "$0" "$@"
# fi
#--------------------------
# Check for Comands needed 
#--------------------------
if ! [ -x "$(command -v python3)" ]; then
    echo "ERROR: python is not installed! Please install python first."
    exit 1
fi
if ! [ -x "$(command -v git)" ]; then
    echo "ERROR: git is not installed! Please install git first."
    exit 1
fi
#---------------------------------------
# Define the colors for the echo output
#---------------------------------------
export ePF="\x1B[35m"   # echo Color (Purple) for Path and File outputs
export eGI="\x1B[32m"   # echo Color (Green) for Git-Urls
export eTG="\x1B[31m"   # echo Color (Red) for Targets
export eSR="\x1B[9;31m" # echo Color (Strikethrough in Red) for Skipped Targets
export eUS="\x1B[34m"   # echo Color (blue) for Files that are executed or used 
export eNO="\x1B[0m"    # Back to    (Black)
#------------------------------------
# Set the current path of the script
export SH_ROOT=$(pwd)
#-----------------------------------------------------------------------------
# Load the functions extractFileName() > For pretty output of compiler configs
source $SH_ROOT/extractConfigFNs.sh
#---------------------------
# Show intro of the build.sh 
echo -e "\n~~~~~~~~~~~~~~~~~ $eTG Starting of the build.sh $eNO to get the Arduino-Libs ~~~~~~~~~~~~~~~~~"
echo -e   "~~ Purpose: Get the Arduino-Libs for manifold  ESP32-Variants > Targets"
echo -e   "~~          It will generate 'Static Libraries'-Files (*.a) and 'Bootloader'-Files (*.elf)"
echo -e   "~~          along with may others neeed files."
echo -e   "~~ Steps of Sricpt:"
echo -e   "~~          1) Check & Process Parameter with calling build.sh"
echo -e   "~~          2) Load or Update Components/Tools to do compile"
echo -e   "~~          3) Compile the Targets with the given Configurations"
echo -e   "~~          4) Create outputs and move this files"
echo -e   "~~ build.sh started at Folder (SH_ROOT):"
echo -e   "~~          >>$ePF $SH_ROOT $eNO"
echo -e   "~~          >> Bash version:$eGI $BASH_VERSION $eNO"
echo -e   "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
#-----------------------------------------------------------
# Set the default values to be overwritten by the arguments
TARGET="all"
BUILD_TYPE="all"
BUILD_DEBUG="default"
SKIP_ENV=0
COPY_OUT=0
ARCHIVE_OUT=0
IDF_InstallSilent=0     # 0 = not silent, 1 = silent
IS_Shown=0              # Flag to show message only once
IDF_BuildTargetSilent=0 # 0 = not silent, 1 = silent
BTS_Shown=0
IDF_BuildInfosSilent=0  # 0 = not silent, 1 = silent
BTI_Shown=0
if [ -z $DEPLOY_OUT ]; then
    DEPLOY_OUT=0
fi
#-------------------------------------
#  Function to print the help message
function print_help() {
    echo "Usage: build.sh [-s] [-A <arduino_branch>] [-I <idf_branch>] [-D <debug_level>] [-i <idf_commit>] [-c <path>] [-t <target>] [-b <build|menuconfig|reconfigure|idf-libs|copy-bootloader|mem-variant>] [config ...]"

    echo "       -p     <arduino-esp32> Set local FOLDER to Arduino-Component instead of components/arduino (AR_PATH)"
    echo "       -A     <arduino-esp32> Set BRANCH to be used for compilation (AR_BRANCH)"
    echo "       -a     <arduino-esp32> Set COMMIT to be used for compilation (AR_COMMIT)"

    echo "       -f     <esp-idf>       Set local FOLDER to ESP-IDF-Component instead of components/esp-idf (IDF_PATH)" 
    echo "       -s     <esp-idf>       Skip installing/updating of ESP-IDF and all components"
    echo "       -I     <esp-idf>       Set BRANCH to be used for compilation (IDF_BRANCH)"
    echo "       -i     <esp-idf>       Set COMMIT to be used for compilation (IDF_COMMIT)"
    echo "      <OR>    only '-I' <OR> '-i' can be used"
    echo "       -D     <esp-idf>       Set DEBUG level compilation. One of default,none,error,warning,info,debug or verbose"

    echo "       -e     Archive the build to dist"
    echo "       -d     Deploy the build to github arduino-esp32"

    echo "       -c     Set the arduino-esp32 folder to copy the result to. ex. '$HOME/Arduino/hardware/espressif/esp32'"
    echo "       -o     Set a own Out-Folder. It will take the building output and works with simlink, placed in normal out-folder"
    echo "       -t     Set the build target(chip) ex. 'esp32s3' or select multiple targets(chips) by separating them with comma ex. 'esp32,esp32s3,esp32c3'"

    echo "       -S     Silent mode for Installation - Components. Don't use this unless you are sure the installs goes without errors"
    echo "       -V     Silent mode for Building - Targets with idf.py. Don't use this unless you are sure the buildings goes without errors"
    echo "       -W     Silent mode for Creating - Infos. Don't use this unless you are sure the creations goes without errors"

    echo "       -b     Set the build type. ex. 'build' to build the project and prepare for uploading to a board"
    echo "       ...    Specify additional configs to be applied. ex. 'qio 80m' to compile for QIO Flash@80MHz. Requires -b"
    exit 1
}
#-------------------------------------
# Check if any arguments were passed
if [ $# -eq 0 ]; then
    # Check if the script is running with bashdb (debug mode)
    if [[ -n "$_Dbg_file" ]]; then
        echo "Running in debug mode"
        source $SH_ROOT/setMyParameters.sh
    else
        # No arguments were passed then set MY defaults
        # Dialog to decide it to use the default values or not
        echo "No Parameters were passed:"
        while true; do
            read -p "Do you want to use your default Parameters? (y/n): " choice
            case "$choice" in
                y|yes ) 
                    source $SH_ROOT/setMyParameters.sh
                    break
                    ;;
                n|No ) 
                    echo "Proceed without Parameters..."
                    break
                    ;;
                * ) 
                    echo "Please answer y or n."
                    ;;
            esac
        done
    fi
fi
# Process Arguments were passed
echo -e "\n----------------------- 1) Given ARGUMENTS Process & Check ------------------------"
while getopts ":A:a:p:I:f:i:c:o:t:b:D:sdeSVW" opt; do
    case ${opt} in
        s )
            SKIP_ENV=1
            echo -e '-s \t..\t Skip installing/updating of ESP-IDF and all components'
            ;;
        d )
            DEPLOY_OUT=1
            echo -e '-d \t..\t Deploy the build to github arduino-esp32'
            ;;
        e )
            ARCHIVE_OUT=1
            echo -e '-e \t..\t Archive the build to dist-Folder'
            ;;
        c )
            export ESP32_ARDUINO="$OPTARG"
            echo -e "-c \t..\t Copy the build to arduino-esp32 Folder:"
            echo -e "+\t\t$ePF >> '$ESP32_ARDUINO' $eNO"
            COPY_OUT=1
            ;;
        o )
            export AR_OWN_OUT="$OPTARG"
            echo -e "-o \t..\t Use a own out-Folder (AR_OWN_OUT):"
            echo -e "+\t\t$ePF >> '$AR_OWN_OUT' $eNO"
            ;;
        A )
            export AR_BRANCH="$OPTARG"
            echo -e "-A  <ar.-esp32>\t Set BRANCH to be used for compilation (AR_BRANCH)=$eTG'$AR_BRANCH'$eNO"
            ;;
        a )
            export AR_COMMIT="$OPTARG"
            echo -e "-a  <ar.-esp32>\t Set COMMIT to be used for compilation (AR_COMMIT):$eTG '$AR_COMMIT' $eNO"
            ;;
        p )
            export AR_PATH="$OPTARG"
            mkdir -p $AR_PATH # Create the Folder if it does not exist otherwise downloads will fail
            echo -e "-p  <ar.-esp32>\t Set local Arduino-Component Folder (AR_PATH):"
            echo -e "+\t\t$ePF >> '$AR_PATH' $eNO"
            ;;
        I )
            export IDF_BRANCH="$OPTARG"
            echo -e "-I  <esp-idf>\t Set BRANCH to be used for compilation (IDF_BRANCH):$eTG '$IDF_BRANCH' $eNO"
            ;;
        f )
            export IDF_PATH="$OPTARG"
            echo -e "-f  <esp-idf>\t Set local IDF-Folder (IDF_PATH):"
            echo -e "+\t\t$ePF >> '$IDF_PATH' $eNO"
            ;;
        i )
            export IDF_COMMIT="$OPTARG"
            echo -e "-i  <esp-idf>\t Set COMMIT to be used for compilation (IDF_COMMIT):$eTG '$IDF_COMMIT' $eNO"
            ;;
        D )
            BUILD_DEBUG="$OPTARG"
            echo -e "-D  <esp-idf>\t Set DEBUG level compilation (BUILD_DEBUG):$eTG '$BUILD_DEBUG' $eNO"
            ;;
        t )
            IFS=',' read -ra TARGET <<< "$OPTARG"
            echo -e "-t \t..\t Set the build target(chip):$eTG '${TARGET[@]}' $eNO"
            ;;
        S )
            IDF_InstallSilent=1
            echo -e '-S \t..\t Silent mode for installing ESP-IDF and components'
            ;;
        V )
            IDF_BuildTargetSilent=1
            echo -e '-V \t..\t Silent mode for building Targets with idf.py'
            ;;
        W )
            IDF_BuildInfosSilent=1
            echo -e '-W \t..\t Silent mode for building of Infos.'
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
            echo -e '-b \t Set the build type BUILD_TYPE='$BUILD_TYPE
            ;;
        \? )
            echo -e $eTG "Invalid option: -$OPTARG $eNO" 1>&2
            print_help
            ;;
        : )
            echo -e $eTG "Invalid option: -$OPTARG requires an argument$eNO" 1>&2
            print_help
            ;;
    esac
done
echo -e   "-------------------------   DONE:  processing ARGUMENTS   -------------------------\n"
# --------------------
# Misc
shift $((OPTIND -1))
CONFIGS=$@
# **********************************************
# ******     LOAD needed Components      *******
# **********************************************
if [ $SKIP_ENV -eq 0 ]; then
    echo -e '---------------------------- 2) Load the Compontents ------------------------------'
    echo -e '-- Load arduino_tinyusb component'
    # update components from git
    source $SH_ROOT/tools/update-components.sh
    if [ $? -ne 0 ]; then exit 1; fi    
    echo -e '\n-- Load arduino-esp32 component'
    # install arduino component
    source $SH_ROOT/tools/install-arduino.sh
    osascript -e 'beep 3' # Beep 3 times
    if [ $? -ne 0 ]; then exit 1; fi
    # install esp-idf
    echo -e '\n-- Load esp-idf component'
    source $SH_ROOT/tools/install-esp-idf.sh
    osascript -e 'beep 3' # Beep 3 times
    if [ $? -ne 0 ]; then exit 1; fi
    echo -e   '----------------------------- Components load DONE  -------------------------------\n'
else
    echo -e '\n--- NO load of Components: Just get the Pathes ----'
    # $IDF_PATH/install.sh
    # source $IDF_PATH/export.sh
    source $SH_ROOT/tools/config.sh
    echo -e   '--- NO load of Components: DONE--------------------\n'
fi
# Hash of managed components
if [ -f "$AR_MANAGED_COMPS/espressif__esp-sr/.component_hash" ]; then
    rm -rf $AR_MANAGED_COMPS/espressif__esp-sr/.component_hash
fi

#------------------------------------------------------------------------
# TESTING DEBUGING ONLY - TESTING DEBUGING ONLY - TESTING DEBUGING ONLY
if [ -z $SKIP_BUILD ]; then  # SKIP BUILD for testing purpose ONLY
# **********************************************
# *****   Build II ALL   ******
# **********************************************
if [ "$BUILD_TYPE" != "all" ]; then
    echo -e '----------------- 3)BUILD Target-List (NOT ALL) -----------------'
    
    if [ "$TARGET" = "all" ]; then
        echo "ERROR: You need to specify target for non-default builds"
        print_help
    fi
    # Target Features Configs
    echo -e '***** Loop over given the Targets *****'
    for target_json in `jq -c '.targets[]' configs/builds.json`; do
        # Get the target name from the json
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
        echo "-- Building for Target:$target"
        # Configs From Arguments
        for conf in $CONFIGS; do
        echo "   ...Get his configs"
            configs="$configs;configs/defconfig.$conf"
        done
        echo -e "   ...Build with >$eUS idf.py$eNO -DIDF_TARGET=\"$target\" -DSDKCONFIG_DEFAULTS=\"$configs\" $BUILD_TYPE"
        rm -rf build sdkconfig
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$configs" $BUILD_TYPE
        if [ $? -ne 0 ]; then exit 1; fi
        echo    "   Building for Target:$target DONE"
    done
    echo -e '----------------- BUILD Target-List   DONE    -----------------\n'
    exit 0
fi
# **********************************************
# ******     BUILD the Components        *******
# **********************************************
echo -e '--------------------------- 3) BUILD for Named Targets ----------------------------'
# Clean the build- and out- folders
rm -rf build sdkconfig out
# -----------------------------------------------------
# Processing own AR_OUT Path with AR_OWN_OUT is given
# -----------------------------------------------------
OUT_FOLDER=$AR_OUT
if [ ! -z $AR_OWN_OUT ]; then
	# ********  Other out Foder locations ********
    # Remove all content from AR_OWN_OUT foler
    rm -rf $AR_OWN_OUT/*
	mkdir -p $AR_OWN_OUT # Create the Folder if it does not exist
	# Create a symlink
	if [ ! -e $AR_OUT ]; then
		# from  <Source>  to  <target> new Folder that's symlink
		ln -s   $AR_OWN_OUT   $AR_OUT > /dev/null
	fi
    OUT_FOLDER=$AR_OWN_OUT 
fi
echo -e "-- Create the Out-folder\n   to:$ePF $OUT_FOLDER $eNO"
# ----------------------------------------------
# Count the number of POSSIBLE targets to build
# ----------------------------------------------
# Therefore create a array from from JSON File: 'configs/builds.json'
# Extract the Possible Target-Names 
possibleTargetsArray=($(jq -r '.targets[].target' configs/builds.json)) # -r option to get raw output, leads to an array 
# And count the number of elements in the array   
targetsCount=${#possibleTargetsArray[@]}
echo -e "...Number of POSSIBLE Targets=$eTG $targetsCount$eNO" 
echo -e "   List:$eUS ${possibleTargetsArray[@]}$eNO"

echo -e "###################      Loop over given Target      ###################"
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
            echo -e "-- Skipping Target: $eSR$target$eNO"
            continue
        fi
    fi
    # Skip chips that should not be a part of the final libs
    # WARNING!!! this logic needs to be updated when cron builds are split into jobs
    if [ "$TARGET" = "all" ] && [ $target_skip -eq 1 ]; then
        echo -e "-- Skipping Target: $eSR$target$eNO"
        continue
    fi
    echo -e "*******************   Building for Target:$eTG $target $eNO  *******************"
    echo -e "-- Target Out-folder"
    echo -e "   to:$ePF $OUT_FOLDER/esp32-arduino-libs/$eTG$target $eNO" 
    #-------------------------
    # Build Main Configs List
    #-------------------------
    echo "-- 1) Getting his Configs-List"
    main_configs="configs/defconfig.common;configs/defconfig.$target;configs/defconfig.debug_$BUILD_DEBUG"
    for defconf in `echo "$target_json" | jq -c '.features[]' | tr -d '"'`; do
        main_configs="$main_configs;configs/defconfig.$defconf"
    done
    #---------------------
    # Build IDF Libs List
    #---------------------
    echo "-- 2) Getting his Lib-List"
    idf_libs_configs="$main_configs"
    for defconf in `echo "$target_json" | jq -c '.idf_libs[]' | tr -d '"'`; do
        idf_libs_configs="$idf_libs_configs;configs/defconfig.$defconf"
    done
    if [ -f "$AR_MANAGED_COMPS/espressif__esp-sr/.component_hash" ]; then
        rm -rf $AR_MANAGED_COMPS/espressif__esp-sr/.component_hash
    fi
    #----------------
    # Build IDF Libs
    #----------------
    echo "-- 3) Build IDF-Libs for the target"
    rm -rf build sdkconfig
    echo -e "   Build with >$eUS idf.py$eNO -Target:$eTG $target $eNO"
    echo -e "     -Config:$eUS "$(extractFileName $idf_libs_configs)"$eNO"
    echo -e "     -Mode:   idf-libs to $ePF.../$eTG$target$ePF/lib$eNO (*.a)"
    if [ $IDF_BuildTargetSilent -eq 1 ]; then
        [ $BTS_Shown -eq 0 ] && echo -e "  $eTG Silent Build$eNO - don't use this as long as your not sure build goes without errors!" && BTS_Shown=1
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" idf-libs > /dev/null 2>&1
    else 
        idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" idf-libs
    fi
    osascript -e 'beep 3' # Beep 3 times
    if [ $? -ne 0 ]; then exit 1; fi
    #----------------
    # Build SR Models
    #-----------------
    if [ "$target" == "esp32s3" ]; then
        echo " -- 3b) Build SR (esp32s3) Models for the target"
        echo -e "   Build with >$eUS idf.py$eNO -Target:$eTG $target $eNO"
        echo -e "     -Config:$eUS "$(extractFileName $idf_libs_configs)"$eNO"
        echo -e "     -Mode:   srmodels_bin"
        if [ $IDF_BuildTargetSilent -eq 1 ]; then
            [ $BTS_Shown -eq 0 ] && echo -e "  $eTG Silent Build$eNO - don't use this as long as your not sure build goes without errors!" && BTS_Shown=1
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" srmodels_bin > /dev/null 2>&1
        else
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$idf_libs_configs" srmodels_bin
        fi
        osascript -e 'beep 3' # Beep 3 times
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
    #-------------------
    # Build Bootloaders
    #-------------------
    countBootloaders=0
    for boot_conf in `echo "$target_json" | jq -c '.bootloaders[]'`; do
        bootloader_configs="$main_configs"
        for defconf in `echo "$boot_conf" | jq -c '.[]' | tr -d '"'`; do
            bootloader_configs="$bootloader_configs;configs/defconfig.$defconf";
        done
        countBootloaders=$((countBootloaders+1))
        if [ -f "$AR_MANAGED_COMPS/espressif__esp-sr/.component_hash" ]; then
            rm -rf $AR_MANAGED_COMPS/espressif__esp-sr/.component_hash
        fi
        echo "-- 4.$countBootloaders) Build BootLoader"
        rm -rf build sdkconfig
        echo -e "   Build with >$eUS idf.py$eNO -Target:$eTG $target $eNO"
        echo -e "     -Config:$eUS "$(extractFileName $bootloader_configs)"$eNO"
        echo -e "     -Mode:   copy-bootloader to $ePF.../$eTG$target/$ePF/bin$eNO (*.elf)"     
        if [ $IDF_BuildTargetSilent -eq 1 ]; then
            [ $BTS_Shown -eq 0 ] && echo -e "  $eTG Silent Build$eNO - don't use this as long as your not sure build goes without errors!" && BTS_Shown=1
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$bootloader_configs" copy-bootloader > /dev/null 2>&1
        else
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$bootloader_configs" copy-bootloader
        fi
        if [ $? -ne 0 ]; then exit 1; fi
        osascript -e 'beep 3' # Beep 3 times
    done
    #-----------------------
    # Build Memory Variants
    #-----------------------
    echo "-- 5) Build Memory Variants for the target"
    for mem_conf in `echo "$target_json" | jq -c '.mem_variants[]'`; do
        mem_configs="$main_configs"
        for defconf in `echo "$mem_conf" | jq -c '.[]' | tr -d '"'`; do
            mem_configs="$mem_configs;configs/defconfig.$defconf";
        done

        if [ -f "$AR_MANAGED_COMPS/espressif__esp-sr/.component_hash" ]; then
            rm -rf $AR_MANAGED_COMPS/espressif__esp-sr/.component_hash
        fi
        rm -rf build sdkconfig
        echo -e "   Build with >$eUS idf.py$eNO -Target:$eTG $target $eNO"
        echo -e "     -Config:$eUS "$(extractFileName $mem_configs)"$eNO"
        echo -e "     -Mode:   mem-variant to $ePF.../$eTG$target$ePF/dio_qspi$eNO and/or$ePF qio_qspi$eNO (*.a)"
        if [ $IDF_BuildTargetSilent -eq 1 ]; then
            [ $BTS_Shown -eq 0 ] && echo -e "  $eTG Silent Build$eNO - don't use this as long as your not sure build goes without errors!" && BTS_Shown=1
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$mem_configs" mem-variant > /dev/null 2>&1
        else
            idf.py -DIDF_TARGET="$target" -DSDKCONFIG_DEFAULTS="$mem_configs" mem-variant
        fi
        if [ $? -ne 0 ]; then exit 1; fi
        osascript -e 'beep 3' # Beep 3 times
    done
    echo -e "****************  FINISHED Building for Target:$eTG $target $eNO  ***************"
done
# Clean the build-folder and sdkconfig
rm -rf build sdkconfig
echo -e '-------------------------- DONE: BUILD for Named Targets --------------------------'
# TESTING DEBUGING ONLY - TESTING DEBUGING ONLY - TESTING DEBUGING ONLY
fi
#------------------------------------------------------------------------# **********************************************
# ******  Add components version info    *******
# **********************************************
echo -e '----------------------------- 4) Create Version Info ------------------------------'
################################
# Create NEW Version Info-File
################################
echo -e '-- Create NEW Version Info-File (one file, not Target-specific!)'
echo -e "   at: $ePF$OUT_FOLDER/tools/esp32-arduino-libs/versions.txt$eNO"
rm -rf "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write lib-builder version
# -------------------------
echo -e '   ...a) Write Lib-Builder Version'
component_version="lib-builder: "$(git -C "$AR_ROOT" symbolic-ref --short HEAD || git -C "$AR_ROOT" tag --points-at HEAD)" "$(git -C "$AR_ROOT" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write ESP-IDF version
# -------------------------
echo -e '   ...b) Write esp-idf Version'
component_version="esp-idf: "$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)" "$(git -C "$IDF_PATH" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write components version
# -------------------------
echo -e '   ...c) Components Versions'
for component in `ls "$AR_COMPS"`; do
    compPath=$(realpath "$AR_COMPS/$component")
    gitFile="$compPath/.git"
    if [ -d "$gitFile" ]; then
        component_version="$component: "$(git -C "$compPath" symbolic-ref --short HEAD || git -C "$compPath" tag --points-at HEAD)" "$(git -C "$compPath" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done
# -------------------------
# Write TinyUSB version
# -------------------------
echo -e '   ...d) Write TinyUSB Version'
component_version="tinyusb: "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" symbolic-ref --short HEAD || git -C "$AR_COMPS/arduino_tinyusb/tinyusb" tag --points-at HEAD)" "$(git -C "$AR_COMPS/arduino_tinyusb/tinyusb" rev-parse --short HEAD)
echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
# -------------------------
# Write managed components version
# -------------------------
echo -e '   ...e) Write Managed components version'
for component in `ls "$AR_MANAGED_COMPS"`; do
    if [ -d "$AR_MANAGED_COMPS/$component/.git" ]; then
        component_version="$component: "$(git -C "$AR_MANAGED_COMPS/$component" symbolic-ref --short HEAD || git -C "$AR_MANAGED_COMPS/$component" tag --points-at HEAD)" "$(git -C "$AR_MANAGED_COMPS/$component" rev-parse --short HEAD)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    elif [ -f "$AR_MANAGED_COMPS/$component/idf_component.yml" ]; then
        component_version="$component: "$(cat "$AR_MANAGED_COMPS/$component/idf_component.yml" | grep "^version: " | cut -d ' ' -f 2)
        echo $component_version >> "$AR_TOOLS/esp32-arduino-libs/versions.txt"
    fi
done
# #########################################
# Generate JSONs
#    - package_esp32_index.template.json
#    - tools.json
# #########################################
if [ "$BUILD_TYPE" = "all" ]; then
    # - package_esp32_index.template.json
    echo -e "-- Generate $eUS'package_esp32_index.template.json'$eNO (One file, not Target-specific!)"
    echo -e "   to: $ePF $OUT_FOLDER/package_esp32_index.template.json $eNO"
    if [ $IDF_BuildInfosSilent -eq 1 ]; then
        [ $BTI_Shown -eq 0 ] && echo -e "  $eTG Silent Info creation$eNO - don't use this as long as your not sure creation goes without errors!" && BTI_Shown=1
        python3 $SH_ROOT/tools/gen_tools_json.py -i "$IDF_PATH" -j "$AR_COMPS/arduino/package/package_esp32_index.template.json" -o "$AR_OUT/" > /dev/null 2>&1
    else 
        python3 $SH_ROOT/tools/gen_tools_json.py -i "$IDF_PATH" -j "$AR_COMPS/arduino/package/package_esp32_index.template.json" -o "$AR_OUT/" 
    fi
    echo -e "-- Generate $eUS'tools.json'$eNO (One file, not Target-specific!)"
    echo -e "   to: $ePF $OUT_FOLDER/tools/esp32-arduino-libs/tools.json $eNO"
    if [ $IDF_BuildInfosSilent -eq 1 ]; then
        python3 $SH_ROOT/tools/gen_tools_json.py -i "$IDF_PATH" -o "$TOOLS_JSON_OUT/" > /dev/null 2>&1
    else 
        python3 $SH_ROOT/tools/gen_tools_json.py -i "$IDF_PATH" -o "$TOOLS_JSON_OUT/" 
    fi
    # - tools.json
    if [ $? -ne 0 ]; then exit 1; fi
fi
# ###################################
# Generate PlatformIO manifest file
# ###################################
if [ "$BUILD_TYPE" = "all" ]; then
    echo -e "-- Generate$eTG PlatformIO$eNO manifest file $eUS'package.json'$eNO"
    pushd $IDF_PATH >/dev/null
    ibr=$(git describe --all --exact-match 2>/dev/null)
    ic=$(git -C "$IDF_PATH" rev-parse --short HEAD)
    popd >/dev/null
    echo -e "   at:  $ePF $OUT_FOLDER/$eNO"
    echo -e "   with:$eUS $SH_ROOT/tools/gen_platformio_manifest.py $eNO"
    if [ $IDF_BuildInfosSilent -eq 1 ]; then
        [ $BTI_Shown -eq 0 ] && echo -e "  $eTG Silent Info creation$eNO - don't use this as long as your not sure creation goes without errors!" && BTI_Shown=1
        python3 $SH_ROOT/tools/gen_platformio_manifest.py -o "$TOOLS_JSON_OUT/" -s "$ibr" -c "$ic" > /dev/null 2>&1
    else
        python3 $SH_ROOT/tools/gen_platformio_manifest.py -o "$TOOLS_JSON_OUT/" -s "$ibr" -c "$ic"
    fi    
    if [ $? -ne 0 ]; then exit 1; fi
fi
# ##############################################
# Copy everything to arduino-esp32 installation
# ##############################################
if [ $COPY_OUT -eq 1 ]; then
    mkdir -p $ESP32_ARDUINO # Create the Folder if it does not exist
    echo -e '-- Copy all to arduino-esp32 installation path'
    echo -e "   at:  $ePF $ESP32_ARDUINO $eNO"
    echo -e "   with:$eUS $SH_ROOT/tools/copy-to-arduino.sh $eNO"
    source $SH_ROOT/tools/copy-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi
# ##############################################
# push changes to esp32-arduino-libs and create pull request into arduino-esp32
# ##############################################
if [ $DEPLOY_OUT -eq 1 ]; then
    echo -e '-- Push changes to esp32-arduino-libs'
    echo -e "   with:$eUS $SH_ROOT/tools/push-to-arduino.sh $eNO"
    $SH_ROOT/tools/push-to-arduino.sh
    if [ $? -ne 0 ]; then exit 1; fi
fi
# ##############################################
# Write archive with the build stuff
# ##############################################
if [ $ARCHIVE_OUT -eq 1 ]; then
    echo -e "-- Move the build to dist-folder"
    echo -e "   with:$eUS $SH_ROOT/tools/archive-build.sh$TG $TARGET $eNO"
    $SH_ROOT/tools/archive-build.sh "$TARGET"
    if [ $? -ne 0 ]; then exit 1; fi
fi
echo -e '---------------------------- DONE Create Version Info -----------------------------'
osascript -e 'beep 6' # Beep 6 times