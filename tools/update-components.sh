#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE TINYUSB
#
echo "Updating TinyUSB..."
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"
TINYUSB_REPO_DIR="$AR_COMPS/arduino_tinyusb/tinyusb"
if [ ! -d "$TINYUSB_REPO_DIR" ]; then
    git clone "$TINYUSB_REPO_URL" "$TINYUSB_REPO_DIR"
else
    git -C "$TINYUSB_REPO_DIR" fetch && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

echo "Updating Matter v1.3 repository..."
MATTER_REPO_URL="https://github.com/espressif/esp-matter.git"
MATTER_REPO_DIR="$AR_COMPS/espressif__esp_matter"
MATTER_REPO_BRANCH="release/v1.3"
if [ ! -d "$MATTER_REPO_DIR" ]; then
    git clone --depth 1 -b "$MATTER_REPO_BRANCH" "$MATTER_REPO_URL" "$MATTER_REPO_DIR"
else
    git -C "$MATTER_REPO_DIR" fetch && \
    git -C "$MATTER_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
echo "Updating CHIP v1.3 repository..."
CHIP_REPO_URL="https://github.com/espressif/connectedhomeip.git"
CHIP_REPO_DIR="$MATTER_REPO_DIR/connectedhomeip/connectedhomeip"
CHIP_REPO_BRANCH="v1.3-branch"
if [ ! -d "$CHIP_REPO_DIR" ]; then
    git clone --depth 1 -b "$CHIP_REPO_BRANCH" "$CHIP_REPO_URL" "$CHIP_REPO_DIR"
    $CHIP_REPO_DIR/scripts/checkout_submodules.py --platform esp32 darwin --shallow
else
    git -C "$MATTER_REPO_DIR" fetch && \
    git -C "$MATTER_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
echo "Patching CHIP v1.3 repository..."
CHIP_BAD_FILE="$CHIP_REPO_DIR/src/platform/ESP32/bluedroid/ChipDeviceScanner.cpp"
CHIP_PATCH="$AR_PATCHES/matter_chip_ChipDeviceScanner.diff"
if [ ! -e "$CHIP_BAD_FILE" ]; then
    patch $CHIP_BAD_FILE $CHIP_PATCH
else
    echo "Error: $CHIP_BAD_FILE not found. Check the script."
fi
if [ $? -ne 0 ]; then exit 1; fi
echo "Matter v1.3 component is installed and updated."
