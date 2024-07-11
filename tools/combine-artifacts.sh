#!/bin/bash

set -e
mkdir -p out

libs_folder="out/tools/esp32-arduino-libs"

files=$(find dist -name 'arduino-esp32-libs-esp*.tar.gz')
for file in $files; do
    echo "Extracting $file"
    tar zxvf $file -C out
    cat $libs_folder/versions.txt >> $libs_folder/versions_full.txt
done

# Merge versions.txt files
awk -i inplace '!seen[$0]++' $libs_folder/versions_full.txt
mv -f $libs_folder/versions_full.txt $libs_folder/versions.txt

cd $libs_folder && tar zcf ../../../dist/esp32-arduino-libs.tar.gz * && cd ../../..
cp out/package_esp32_index.template.json dist/package_esp32_index.template.json
