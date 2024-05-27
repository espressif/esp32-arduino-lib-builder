#!/bin/bash

# Define the colors for the echo output 
ePF="\x1B[35m" # echo Color (Purple) for Path and File outputs
eNO="\x1B[0m"  # Back to    (Black)

# ---------------------------------------
# *** Set the Folder for the Log File *** 
# ---------------------------------------
logFolder=$(pwd)/../libBuildLogs && logFolder=$(eval echo "$logFolder") && logFolder=$(realpath $logFolder)

#---------------------------------------------------------------------------------- 
# Create a new file with the current timestamp to take the output of an Bash sricpt
#---------------------------------------------------------------------------------- 
timestamp=$(date +"%Y-%m-%d-%Hh_%Mm_%Ss") # %Y: Year # %m: Month # %d: Day # %H: Hour # %M: Minute # %S: Second

logFN="$timestamp-build.log" # Buld your custom FileName
logFile="$logFolder/$timestamp-build.log" # The File with Path
mkdir -p $logFolder # If folder not exist: create it!
touch $logFile # Cretat the new log

# ---------------------------------------
#                RUN
# ---------------------------------------
# Output-Folder handed to build script with option '-c'  
rm -rf /Users/thomas/esp/arduino-esp32
mkdir /Users/thomas/esp/arduino-esp32
# RUN your build script with LogFile '2>&1 | tee $logFile'  # Echo a text to the LogFile and Terminal
echo -e "-- Logging to\n   Folder:$ePF $logFolder $eNO"

# Only build for esp32h2 in silent mode
#./build.sh -t 'esp32h2' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V  2>&1 | tee $logFile

# Build for all my ESP32 variants in silent mode
#./build.sh -t 'esp32h2,esp32s2,esp32c2,esp32' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V  2>&1 | tee $logFile

# Build for all ESP32 variants with full output
./build.sh -t "esp32h2" -A "idf-release/v5.1" -I "release/v5.1" -e -D "error" -c "/Users/thomas/esp/to_arduino-esp32_$timestamp" -W 2>&1 | tee $logFile

#-t 'esp32h2
#-I 'release/v5.1'
#-i "d7b0a45"


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