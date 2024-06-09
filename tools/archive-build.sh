#!/bin/bash

#---------------------------------------------------------
# Get the Infos IDF Infos used for bulid: Commit, Branch 
# to create IDF-Version-String
#---------------------------------------------------------
IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD || echo "")
IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD || echo "")
idf_version_string=${IDF_BRANCH//\//_}"-$IDF_COMMIT"
# ----------------------
# Set the archive path
# ----------------------
         archiveFN="arduino-esp32-libs-$1-$idf_version_string.tar.gz"
#archive_path="dist/arduino-esp32-libs-$1-$idf_version_string.tar.gz"
#-----------------------------------
# Set the DIRERCTORY for the archive
#-----------------------------------
targetFolder=$(realpath $SH_ROOT/../)/dist
if [ ! -z $AR_OWN_OUT ]; then # When own out-Path 
	sourceFolder=$AR_OWN_OUT
else # Normal
	sourceFolder=$SH_ROOT/out
fi
# ---------------------------------------------
# Make DIR and remove Target-File if it exists
# ---------------------------------------------
mkdir -p $targetFolder 
rm -rf "$targetFolder/$archiveFN"
# ---------------------------------------------
# Create the Archive with tar
# ---------------------------------------------
if [ -d $sourceFolder ]; then
	echo -e "   to Folder: $(shortFP $targetFolder)"
	echo -e "   Filename:$ePF  $archiveFN $eNO"
	currentDir=$(pwd)
	cd $sourceFolder # Change to the out-Folder
	tar -zcf "$targetFolder/$archiveFN" * # Create the Archive
	cd $currentDir
	# cd out && tar zcf "../$archive_path" * && cd ..
fi