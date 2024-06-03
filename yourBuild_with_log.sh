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
source setMyParameters.sh                   # Set the parameters
./build.sh  2>&1 | tee $logFile             # Run the build and write the output to the log file
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