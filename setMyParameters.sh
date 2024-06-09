#!/bin/bash

# ----------------------------------
# Set Parameters for the build.sh
# ---------------------------------
# Call his upfront, if you call
#    ./build.sh 
# from a other scrpt,
# see: yourBuild_with_log.sh
# --------------------------------
oneUpDir=$(realpath $(pwd)/../)      # DIR above the current directory
timeStampAR=$(date +"%Y%m%d_%Hh%Mm") # Shorter Timestamp for the arduino-esp32 build
echo "Set Parameters for ./build.sh   by this script >> 'setMyParameters.sh'"
# --------------------------
# Target Chips               (TARGET)      to be build for. Separate them with comma.
# --------------------------
sS+=" -t esp32h2"
# --------------------------
# <arduino-esp32>
# --------------------------
# BRANCH                     (AR_BRANCH)   for the building.  
#sS+=" -A idf-release/v5.1"
# COMMIT                     (AR_COMMIT)   for the building.
sS+=" -a 2ba3ed3"
# FOLDER                     (AR_PATH)     to store it.         
sS+=" -p $oneUpDir/GitHub-Sources/arduino-esp32"
# --------------------------
# <esp-idf>  
# --------------------------
# BRANCH                     (IDF_BRANCH)  for the building.   
sS+=" -I release/v5.1"
# COMMIT                     (IDF_COMMIT)  for the building.   
#sS+=" -i '<commit-hash>'"
# FOLDER                     (IDF_PATH)    to store it.          
sS+=" -f $oneUpDir/GitHub-Sources/esp-idf"
# DEBUG flag                 (BUILD_DEBUG) for compile with idf.py   
sS+=" -D error"
# SKIP                       (SKIP_ENV)    install./update IDF & components. (IDF_InstallSilent)  
#sS+=" -s" 
# ------------------------------------
# Build out Folder & post-Build flags
# ------------------------------------
#        ~~ NO building  ~   (SKIP_BUILD)   SKIP building for TESTING DEBUGING ONLY
#sS+=" -X"
# OUT    ~~ during build ~~  (AR_OWN_OUT)  to store the build output.
sS+=" -o $oneUpDir/Out-from_build"
# Arduino  ~~ post-build ~~  (ESP32_ARDUINO) for use with Arduino.
sS+=" -c $oneUpDir/Arduino/copy/arduino-esp32-$timeStampAR"
# Arduiono  ~~ post-build ~~ (ARCHIVE_OUT) Set flag to create Arduiono archives
sS+=" -e"
# PIO    ~~ post-build ~~    (POI_OUT_F) Set flag to create PIO archives
sS+=" -l"
#-d                          Deploy the build to github arduino-esp32"
# ----------------
# Silent Settings
# ----------------
# Silent mode                (IDF_InstallSilent) for Load & Install - Components. 
sS+=" -S"
# Silent mode                (IDF_BuildTargetSilent) for buildings with idf.py
sS+=" -V" 
# Silent mode                (IDF_BuildInfosSilent) for create output & arrange after build 
sS+=" -W"
# ------------------
# Set the Arguments
# -----------------
set -- $sS

# <arduino-esp32> Find suitable:
# --  BRANCH      https://github.com/espressif/arduino-esp32/branches
# --  COMMIT      https://github.com/espressif/arduino-esp32/commits/master/
# Current choice:
#     commit      2ba3ed3 = IDF release/v5.1 3f9ab2d6a6 (#9770) 

#  <esp-idf>      Find suitable:
# --  BRANCH      https://github.com/espressif/esp-idf/branches
# --  COMMIT      https://github.com/espressif/esp-idf/commits/master/
# Current choice:
#    branch       release/v5.1"