#!/bin/bash

# Define the colors for the echo output 
export ePF="\x1B[35m" # echo Color (Purple) for Path and File outputs
export eGI="\x1B[32m" # echo Color (Green) for Git-Urls
export eTG="\x1B[31m" # echo Color (Red) for Targets
export eUS="\x1B[34m" # echo Color (blue) for Files that are executed or used 
export eNO="\x1B[0m"  # Back to    (Black)

#echo "       -t     Set the build target(chip) ex. 'esp32s3' or select multiple targets(chips) by separating them with comma ex. 'esp32,esp32s3,esp32c3'"
#echo "       -A     Set which branch of arduino-esp32 to be used for compilation"
#echo "       -a     Set local Arduino-Component Folder <arduino-esp32>/<arduino>"
#echo "       -f     Set local IDF Folder <esp-idf>" 
#echo "       -I     Set which branch of ESP-IDF to be used for compilation"
#echo "       -e     Archive the build to dist"
#echo "       -D     Debug level to be set to ESP-IDF. One of default,none,error,warning,info,debug or verbose"
#echo "       -S     Silent mode for installing ESP-IDF and components'
#echo "       -V     Silent mode for building Targets with idf.py'
#echo "       -c     Copy the build to arduino-esp32 Folder'
#echo "       -W     Silent mode for Creating - Infos. Don't use this unless you are sure the creations goes without errors"

optInput="esp32h2"                                             # -t 
IFS=',' read -ra TARGET <<< "$optInput" # 'IFS' ONLY works within bash script
# IFS is a special shell variable - "The Internal Field Separator (IFS)", that determines how Bash recognizes word boundaries.
# IFS=','
#      This part sets the Internal Field Separator (IFS) to a comma (,)
# read -ra TARGET:
#       Reads input into an array named TARGET.
#       -r option tells read to treat backslashes literally (i.e., do not interpret them as escape characters).
#       -a option tells read to split the input into an array based on the IFS.
export TARGET
export AR_BRANCH='idf-release/v5.1'                             # -A
export AR_PATH=$(realpath $(pwd)/../arduino-esp32)              # -a
export IDF_BRANCH='release/v5.1'                                # -I
export IDF_PATH=$(realpath $(pwd)/../esp-idf)                   # -f
export ARCHIVE_OUT=1                                            # -e   
export BUILD_DEBUG="error"                                      # -D
export IDF_InstallSilent=1                                      # -S
export IDF_BuildTargetSilent=1                                  # -V
export IDF_BuildInfosSilent=1                                   # -W
export COPY_OUT=1                                               # -c
timestamp=$(date +"%Y%m%d_%Hh%Mm")                              # -c
export ESP32_ARDUINO=$(realpath $(pwd)/../to_arduino-esp32_$timestamp) # -c
export AR_OWN_OUT=$(realpath $(pwd)/../out)

echo -e "\n-----------------------        1) My default was set        ------------------------"
echo -e "-t \t Set TARGET to build for target(chips):$eTG '${TARGET[@]}' $eNO"
echo -e "-A \t Set branch of arduino-esp32 for compilation:$eTG '$AR_BRANCH' $eNO"
echo -e "-I \t Set branch of ESP-IDF for compilation:$eTG '$IDF_BRANCH' $eNO"
echo -e "-a \t Set local Arduino-Component Folder :$eTG '$AR_PATH' $eNO"
echo -e "-f \t Set Set local IDF-Folder:$eTG '$IDF_PATH' $eNO"
[ $ARCHIVE_OUT -eq 1 ]           && echo -e '-e \t Archive the build to dist-Folder'
echo -e "-D \t Debug level to be set to ESP-IDF:$eTG '$BUILD_DEBUG' $eNO"
[ $IDF_InstallSilent -eq 1 ]     && echo -e '-S \t Silent mode for installing ESP-IDF and components'
[ $IDF_BuildTargetSilent -eq 1 ] && echo -e '-V \t Silent mode for building Targets with idf.py'
[ $IDF_BuildInfosSilent -eq 1 ]  && echo -e '-W \t Silent mode for building of Infos.'
[ $COPY_OUT -eq 1 ]              && echo -e "-c \t Copy the build to arduino-esp32 Folder:"
[ $COPY_OUT -eq 1 ]              && echo -e "+\t$ePF '$ESP32_ARDUINO' $eNO"
echo -e   "-------------------------        DONE:  My defaults        -------------------------\n"