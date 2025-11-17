#!/bin/bash

IDF_TARGET=$1
CHIP_VARIANT=$2
FLASH_MODE="$3"
FLASH_FREQ="$4"
BOOTCONF=$FLASH_MODE"_$FLASH_FREQ"

source ./tools/config.sh

echo "Copying bootloader: $AR_SDK/bin/bootloader_$BOOTCONF.elf"

mkdir -p "$AR_SDK/bin"

cp "build/bootloader/bootloader.elf" "$AR_SDK/bin/bootloader_$BOOTCONF.elf"
