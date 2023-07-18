#!/bin/bash

IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD || echo "")
IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD || echo "")

idf_version_string=${IDF_BRANCH//\//_}"-$IDF_COMMIT"
archive_path="dist/arduino-esp32-libs-$idf_version_string.tar.gz"
# build_archive_path="dist/arduino-esp32-build-$idf_version_string.tar.gz"

mkdir -p dist && rm -rf "$archive_path" "$build_archive_path"
if [ -d "out" ]; then
	cd out && tar zcf "../$archive_path" * && cd ..
fi
# if [ -d "build" ]; then
# 	cd build && tar zcf "../$build_archive_path" * && cd ..
# fi
