#!/bin/bash

set -e
mkdir -p out

libs_folder="out/tools/esp32-arduino-libs"

files=$(find dist -name 'arduino-esp32-libs-esp*.tar.gz')
for file in $files; do
    echo "Extracting $file"
    tar zxf "$file" -C out

    # Extract SoC name from filename (e.g., esp32, esp32s2, esp32s3, etc.)
    soc_name=$(basename "$file" | sed 's/arduino-esp32-libs-\(esp[^-]*\)-.*\.tar\.gz/\1/')

    # Copy versions.txt to the SoC-specific folder before merging
    if [ -f "$libs_folder/versions.txt" ] && [ -d "$libs_folder/$soc_name" ]; then
        cp "$libs_folder/versions.txt" "$libs_folder/$soc_name/versions.txt"
        echo "Saved versions.txt for $soc_name"
    fi

    cat "$libs_folder/versions.txt" >> "$libs_folder/versions_full.txt"
done

# Merge versions.txt files
if [[ "$OSTYPE" == "darwin"* ]]; then
    gawk -i inplace '!seen[$0]++' "$libs_folder/versions_full.txt"
else
    awk -i inplace '!seen[$0]++' "$libs_folder/versions_full.txt"
fi
mv -f "$libs_folder/versions_full.txt" "$libs_folder/versions.txt"

echo "Creating zip file"
cd out/tools && zip -q -r ../../dist/esp32-arduino-libs.zip ./* && cd ../..
