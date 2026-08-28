#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE TINYUSB
#
echo "Updating TinyUSB..."
TINYUSB_REPO_URL="https://github.com/hathach/tinyusb.git"
TINYUSB_REPO_DIR="$AR_COMPS/arduino_tinyusb/tinyusb"
TINYUSB_PATCH_DIR="$AR_PATCHES/tinyusb"
if [ ! -d "$TINYUSB_REPO_DIR" ]; then
    git clone "$TINYUSB_REPO_URL" "$TINYUSB_REPO_DIR"
else
    # The clone is build output, not a workspace: drop the patches of the previous
    # run so pull --ff-only does not trip over them.
    git -C "$TINYUSB_REPO_DIR" checkout -- . && \
    git -C "$TINYUSB_REPO_DIR" fetch && \
    git -C "$TINYUSB_REPO_DIR" pull --ff-only
fi
if [ $? -ne 0 ]; then exit 1; fi

# Fixes we cannot wait for upstream on, see patches/tinyusb/README.md
for patch in "$TINYUSB_PATCH_DIR"/*.diff; do
    [ -e "$patch" ] || continue
    echo "Patching TinyUSB with $(basename "$patch")..."
    git -C "$TINYUSB_REPO_DIR" apply "$patch"
    if [ $? -ne 0 ]; then exit 1; fi
done
