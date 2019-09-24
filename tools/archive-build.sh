#!/bin/bash

idf_version_string=${IDF_BRANCH//\//_}"-$IDF_COMMIT"
archive_path="dist/arduino-esp32-libs-$idf_version_string.tar.gz"

mkdir -p dist && \
rm -rf $archive_path && \
cd out && \
tar zcf ../$archive_path * \
&& cd ..
