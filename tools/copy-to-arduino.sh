#!/bin/bash
source ./tools/config.sh

if [ -z $ESP32_ARDUINO ]; then
    if [[ "$AR_OS" == "macos" ]]; then
    	ESP32_ARDUINO="$HOME/Documents/Arduino/hardware/espressif/esp32"
    else
    	ESP32_ARDUINO="$HOME/Arduino/hardware/espressif/esp32"
    fi
fi

if ! [ -d "$ESP32_ARDUINO" ]; then
	echo "ERROR: Target arduino folder does not exist!"
	exit 1
fi

echo "Installing new libraries to $ESP32_ARDUINO"

rm -rf $ESP32_ARDUINO/package/package_esp32_index.template.json && \
cp -f $AR_OUT/package_esp32_index.template.json $ESP32_ARDUINO/package/package_esp32_index.template.json

rm -rf $ESP32_ARDUINO/tools/esp32-arduino-libs && \
cp -Rf $AR_TOOLS/esp32-arduino-libs $ESP32_ARDUINO/tools/
