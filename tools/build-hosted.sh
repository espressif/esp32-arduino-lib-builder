#!/bin/bash

CCACHE_ENABLE=1

export IDF_CCACHE_ENABLE=$CCACHE_ENABLE
source ./tools/config.sh

SLAVE_DIR="$AR_MANAGED_COMPS/espressif__esp_hosted/slave"

if [ ! -d "$SLAVE_DIR" ]; then
	echo "ESP-Hosted component not found!"
	exit 1
fi

VERSION_FILE="$SLAVE_DIR/main/esp_hosted_coprocessor_fw_ver.h"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: File $VERSION_FILE not found!"
    exit 1
fi

MAJOR=$(grep "PROJECT_VERSION_MAJOR_1" "$VERSION_FILE" | sed 's/.*PROJECT_VERSION_MAJOR_1 \([0-9]*\).*/\1/')
MINOR=$(grep "PROJECT_VERSION_MINOR_1" "$VERSION_FILE" | sed 's/.*PROJECT_VERSION_MINOR_1 \([0-9]*\).*/\1/')
PATCH=$(grep "PROJECT_VERSION_PATCH_1" "$VERSION_FILE" | sed 's/.*PROJECT_VERSION_PATCH_1 \([0-9]*\).*/\1/')

if [ -z "$MAJOR" ] || [ -z "$MINOR" ] || [ -z "$PATCH" ]; then
    echo "Error: Could not extract all version infos!"
    echo "MAJOR: '$MAJOR', MINOR: '$MINOR', PATCH: '$PATCH'"
    exit 1
fi

VERSION="$MAJOR.$MINOR.$PATCH"
echo "Building ESP-Hosted firmware $VERSION"

cd "$SLAVE_DIR"

OUTPUT_DIR="$AR_TOOLS/esp32-arduino-libs/hosted"
mkdir -p "$OUTPUT_DIR"

TARGETS=(
    "esp32c5"
    "esp32c6"
)

for target in "${TARGETS[@]}"; do
    echo "Building for target: $target"
    idf.py set-target "$target"
    idf.py clean
    idf.py build
    cp "$SLAVE_DIR/build/network_adapter.bin" "$OUTPUT_DIR/$target-v$VERSION.bin"
    echo "Build completed: $target-v$VERSION.bin"
done
