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
    # from right before Keyboard LED problem
    # git checkout 69313ef45564cc8967575f47fb8c57371cbea470
    # from right after Keyboard LED problem
    git checkout 7fb8d3341ce2feb46b0bce0bef069d31cf080168
    cd -
else
    git -C "$TINYUSB_REPO_DIR" fetch && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi
