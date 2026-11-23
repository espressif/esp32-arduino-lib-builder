#!/bin/bash
#
# Install one of the prebuilt ESP32-S31 BLE host variants as the active
# esp32s31 library set, optionally building it first.
#
# The published libs ship a single host backend per chip. For the S31 the BLE
# library supports both NimBLE and Bluedroid, so both are built and kept side
# by side under variants/ (outside out/, which build.sh wipes on every run):
#
#   variants/esp32s31_nimble     - default (NimBLE host)
#   variants/esp32s31_bluedroid  - Bluedroid host
#
# This script copies the selected variant to the name the Arduino core and the
# pioarduino/Arduino build scripts look up (esp32s31), in out/ and in the
# Arduino installation. The copy is authoritative: sdkconfig, headers, flags
# and static libs all come from the same build, so the compile-time CONFIG_BT_*
# macros and the linked objects cannot disagree.
#
# With --build, or when the variant does not exist yet, the variant is rebuilt
# from the current tree. The Bluedroid build promotes the only tracked config,
# configs/defconfig.esp32s31_bluedroid.disabled, to
# configs/defconfig.bluedroid for the build and removes the promoted copy again
# on exit (success or failure), so the builder checkout never keeps an active
# overlay. The build needs the IDF environment already exported in the caller's
# shell; source the same esp-idf/export.sh used for the published libs first.
#
# Usage:
#   ./tools/select-ble-backend.sh nimble
#   ./tools/select-ble-backend.sh bluedroid
#   ./tools/select-ble-backend.sh bluedroid --build
#
# ESP32_ARDUINO overrides the Arduino core location (see config.sh).

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# config.sh falls back to the builder's own esp-idf checkout when IDF_PATH is
# not exported. Keep the caller's tree for a build: it is the one with the
# reviewed keep-list patches.
CALLER_IDF_PATH="${IDF_PATH:-}"
source ./tools/config.sh

BUILD=0
BACKEND=""
for arg in "$@"; do
    case "$arg" in
    --build | --rebuild)
        BUILD=1
        ;;
    nimble | bluedroid | esp32s31_nimble | esp32s31_bluedroid)
        BACKEND="$arg"
        ;;
    *)
        echo "usage: $0 {nimble|bluedroid} [--build]" >&2
        exit 1
        ;;
    esac
done

case "$BACKEND" in
nimble | esp32s31_nimble)
    VARIANT="esp32s31_nimble"
    EXTRA_CONFIG=""
    ;;
bluedroid | esp32s31_bluedroid)
    VARIANT="esp32s31_bluedroid"
    EXTRA_CONFIG="bluedroid"
    ;;
*)
    echo "usage: $0 {nimble|bluedroid} [--build]" >&2
    exit 1
    ;;
esac

SRC="$REPO_ROOT/variants/$VARIANT"

build_variant() {
    if [ -z "$CALLER_IDF_PATH" ] || ! command -v idf.py >/dev/null 2>&1; then
        echo "ERROR: the build needs the ESP-IDF environment." >&2
        echo "       source <IDF_PATH>/export.sh first, then rerun with --build." >&2
        exit 1
    fi

    # Do not let config.sh's builder-local default override the caller's tree.
    export IDF_PATH="$CALLER_IDF_PATH"

    local promoted=0
    if [ "$VARIANT" = "esp32s31_bluedroid" ]; then
        cp "$REPO_ROOT/configs/defconfig.esp32s31_bluedroid.disabled" \
            "$REPO_ROOT/configs/defconfig.bluedroid"
        promoted=1
        trap 'rm -f "$REPO_ROOT/configs/defconfig.bluedroid"' EXIT
    fi

    ./build.sh -s -t esp32s31 -b idf-libs qio 80m_250m opi_ram $EXTRA_CONFIG

    rm -rf "$SRC"
    mkdir -p "$REPO_ROOT/variants"
    mv "$REPO_ROOT/out/tools/esp32-arduino-libs/esp32s31" "$SRC"

    if [ "$promoted" = 1 ]; then
        rm -f "$REPO_ROOT/configs/defconfig.bluedroid"
        trap - EXIT
    fi
}

if [ "$BUILD" = 1 ] || [ ! -d "$SRC" ]; then
    echo "* Building BLE host variant: $VARIANT"
    build_variant
fi

if ! [ -d "$SRC" ]; then
    echo "ERROR: variant not built: $SRC" >&2
    exit 1
fi

echo "* Activating BLE host variant: $VARIANT"

# Keep out/ consistent with what is installed, so a later copy-to-arduino.sh
# publishes the same backend.
mkdir -p "$AR_TOOLS/esp32-arduino-libs"
rm -rf "$AR_TOOLS/esp32-arduino-libs/esp32s31"
cp -Rf "$SRC" "$AR_TOOLS/esp32-arduino-libs/esp32s31"

if [ -z "$ESP32_ARDUINO" ]; then
    if [[ "$AR_OS" == "macos" ]]; then
        ESP32_ARDUINO="$HOME/Documents/Arduino/hardware/espressif/esp32"
    else
        ESP32_ARDUINO="$HOME/Arduino/hardware/espressif/esp32"
    fi
fi

if [ -d "$ESP32_ARDUINO/tools/esp32-arduino-libs" ]; then
    echo "* Installing into $ESP32_ARDUINO/tools/esp32-arduino-libs"
    rm -rf "$ESP32_ARDUINO/tools/esp32-arduino-libs/esp32s31"
    cp -Rf "$SRC" "$ESP32_ARDUINO/tools/esp32-arduino-libs/esp32s31"
fi
