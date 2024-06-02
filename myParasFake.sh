#!/bin/bash

# -----------------
# Fake parameters
# -----------------
oneUpDir=$(realpath $(pwd)/../)      # DIR above the current directory
timeStampAR=$(date +"%Y%m%d_%Hh%Mm") # Shorter Timestamp for the arduino-esp32 build
set -- \
"-t" "esp32h2,esp32s3" \
"-A" "idf-release/v5.1" \
"-a" "$oneUpDir/arduino-esp32" \
"-I" "release/v5.1" \
"-f" $"$oneUpDir/esp-idf" \
"-D" "error" \
"-c" "$oneUpDir/to_arduino-esp32_$timeStampAR" \
"-o" "$oneUpDir/out" \
"-e" "-S" "-V" "-W"
echo "Parameters set successfully."