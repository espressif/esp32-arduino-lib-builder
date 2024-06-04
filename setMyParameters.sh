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
set -- \
"-t" "esp32h2" \
"-A" "idf-release/v5.1" \
"-a" "$oneUpDir/GitHub-Sources/arduino-esp32" \
"-I" "release/v5.1" \
"-f" $"$oneUpDir/GitHub-Sources/esp-idf" \
"-D" "error" \
"-c" "$oneUpDir/to-arduino-esp32-$timeStampAR" \
"-o" "$oneUpDir/Out-from_build" \
"-e" "-S" "-V" "-W"
echo "Parameters set successfully."
