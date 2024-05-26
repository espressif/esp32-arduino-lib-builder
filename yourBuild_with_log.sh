#!/bin/bash

# Define the colors for the echo output 
ePF="\x1B[35m" # echo Color (Purple) for Path and File outputs
eNO="\x1B[0m"  # Back to    (Black)

# ---------------------------------------
# *** Set the Folder for the Log File *** 
# ---------------------------------------
logFolder=$(pwd)/../libBuildLogs && logFolder=$(eval echo "$logFolder") # Set the Folder for the Log File

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
echo -e "-- Logging\n   to:$ePF $logFile $eNO"
./build.sh -t 'esp32h2' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V  2>&1 | tee $logFile
#./build.sh -t 'esp32h2,esp32s2,esp32c2,esp32' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V  2>&1 | tee $logFile

# ---------------------------------------
#           REPLAY a LOG FILE
# ---------------------------------------
#echo "$(<$logFile)" 