#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE TINYUSB
#
echo "...Component TinyUSB installing/updating local copy...."
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"
TINYUSB_REPO_DIR="$AR_COMPS/arduino_tinyusb/tinyusb"

echo -e "   cloning $eGI $TINYUSB_REPO_URL to $ePF $TINYUSB_REPO_DIR $eNo $eNO"


echo -e "   cloning $eGI $TINYUSB_REPO_URL $eNo\n   to:$ePF $TINYUSB_REPO_DIR $eNo"
if [ ! -d "$TINYUSB_REPO_DIR" ]; then
    git clone "$TINYUSB_REPO_URL" "$TINYUSB_REPO_DIR"  --quiet
else
    git -C "$TINYUSB_REPO_DIR" fetch --quiet && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only --quiet
fi
if [ $? -ne 0 ]; then exit 1; fi
