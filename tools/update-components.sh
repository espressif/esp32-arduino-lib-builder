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
    # Temporary fix given that tinyusb/master is breaking Lib Builder
    cd "$TINYUSB_REPO_DIR"
    # from  Sep 18, 2024
    git checkout 40b55170c87da109b3416ac80eaa55ca56eadc77
    cd -
else
    git -C "$TINYUSB_REPO_DIR" fetch && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
