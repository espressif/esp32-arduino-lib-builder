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
archive_path="dist/arduino-esp32-libs-$1-$idf_version_string.tar.gz"
echo -e "   to:$ePF   $archive_path$eNO"
# ---------------------------------------------
# Make DIR and remove Target-File if it exists
# ---------------------------------------------
mkdir -p dist && rm -rf "$archive_path"
# ---------------------------------------------
# Create the Archive with tar
# ---------------------------------------------
if [ -d "out" ]; then
	cd out && tar zcf "../$archive_path" * && cd ..
fi