#/bin/bash

source $SH_ROOT/tools/config.sh

#
# CLONE/UPDATE TINYUSB
#
echo "...Component TinyUSB installing/updating local copy...."
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"
TINYUSB_REPO_DIR="$AR_COMPS/arduino_tinyusb/tinyusb"


# Check if the directory exists and clone or update
if [ ! -d "$TINYUSB_REPO_DIR" ]; then
    echo -e "   cloning$eGI $TINYUSB_REPO_URL $eNO\n   to: $(shortFP $TINYUSB_REPO_DIR)"
    git clone "$TINYUSB_REPO_URL" "$TINYUSB_REPO_DIR"  --quiet
else
    echo -e "   updating (already there)$eGI $TINYUSB_REPO_URL $eNO\n   to: $(shortFP $TINYUSB_REPO_DIR)"
    git -C "$TINYUSB_REPO_DIR" fetch --quiet && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only --quiet
fi
if [ $? -ne 0 ]; then exit 1; fi
