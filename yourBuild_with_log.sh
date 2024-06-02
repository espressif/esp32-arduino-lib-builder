#!/bin/bash
# ---------------------------------------
# Define the colors for the echo output
# ---------------------------------------
ePF="\x1B[35m" # echo Color (Purple) for Path and File outputs
eNO="\x1B[0m"  # Back to    (Black)
# ---------------------------------------
# *** Set the Folder for the Log File *** 
# ---------------------------------------
oneUpDir=$(realpath $(pwd)/../)         # DIR above the current directory
logFolder=$oneUpDir/libBuildLogs        # Log-Folder
mkdir -p $logFolder                     # If folder not exist: create it
#-------------------------------------------------------------------------------------- 
# Create a new Log-File with the current timestamp to take the output of an Bash sricpt
#--------------------------------------------------------------------------------------
timestamp=$(date +"%Y-%m-%d-%Hh_%Mm_%Ss")   # %Y: Year # %m: Month # %d: Day # %H: Hour # %M: Minute # %S: Second
timeStampAR=$(date +"%Y%m%d_%Hh%Mm")        # Shorter Timestamp for the arduino-esp32 build
startTime=$(date +"%s")                     # Fix the Start Time of builing
logFN="$timestamp-build.log"                # Log File Name
logFile="$logFolder/$timestamp-build.log"   # The File with Path
touch $logFile                              # Cretat the new log
echo -e "-- Logging to\n   Folder:$ePF $logFolder $eNO"
# ---------------------------------------
#                RUN
# ---------------------------------------
# Build for all ESP32 variants with full output
./build.sh \
    -t "esp32h2" \
    -A "idf-release/v5.1" \
    -a "$oneUpDir/arduino-esp32" \
    -I "release/v5.1" \
    -f $"$oneUpDir/esp-idf" \
    -D "error" \
    -c "$oneUpDir/to_arduino-esp32_$timeStampAR" \
    -o "$oneUpDir/out" \
    -e -S -V -W 2>&1 | tee $logFile
# ------------------------------------------------
# Write Start-, End- and Run-Time to the LogFile
# ------------------------------------------------
# Calculate the runtime
runtime=$(($(date +"%s")- startTime))
hours=$((runtime / 3600)) &&  minutes=$(( (runtime % 3600) / 60 )) && seconds=$((runtime % 60))
# Write times
echo -e "Started:\t$timestamp" &&
echo -e "Finihed:\t$(date +"%Y-%m-%d-%Hh_%Mm_%Ss")" | tee $logFile
echo -e "Runtime:\t${hours}h-${minutes}m-${seconds}s" | tee $logFile

# ---------------------------------------
#           REPLAY a LOG FILE
# ---------------------------------------
#less -R $logFile"
#cat $logFile
#tail -f $logFile

# Usage: build.sh [-s] [-A <arduino_branch>] [-I <idf_branch>] [-D <debug_level>] [-i <idf_commit>] [-c <path>] [-t <target>] [-b <build|menuconfig|reconfigure|idf-libs|copy-bootloader|mem-variant>] [config ...]
#        -s     Skip installing/updating of ESP-IDF and all components
#        -A     Set which branch of arduino-esp32 to be used for compilation - https://github.com/espressif/arduino-esp32
#        -I     Set which branch of ESP-IDF to be used for compilation       - https://github.com/espressif/esp-idf
#        -F     Set IDF-Path/Folder so need to clone the ESP-IDF repetitively for each build
#        -i     Set which commit of ESP-IDF to be used for compilation
#        -e     Archive the build to dist
#        -d     Deploy the build to github arduino-esp32
#        -D     Debug level to be set to ESP-IDF. One of default,none,error,warning,info,debug or verbose
#        -c     Set the arduino-esp32 folder to copy the result to. ex. '/Users/thomas/Arduino/hardware/espressif/esp32'
#        -t     Set the build target(chip) ex. 'esp32s3' or select multiple targets(chips) by separating them with comma ex. 'esp32,esp32s3,esp32c3'
#        -S     Silent mode for Installation - Components. Don't use this unless you are sure the installs goes without errors
#        -V     Silent mode for Building - Targets with idf.py. Don't use this unless you are sure the buildings goes without errors
#        -W     Silent mode for Creating - Infos. Don't use this unless you are sure the creations goes without errors
#        -b     Set the build type. ex. 'build' to build the project and prepare for uploading to a board
#        ...    Specify additional configs to be applied. ex. 'qio 80m' to compile for QIO Flash@80MHz. Requires -b