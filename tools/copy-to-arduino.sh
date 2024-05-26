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

# Copy the Libraries to the Arduino folder
# ---------------------------------------
echo -e "   Installing new Libraries, try to copy..."
echo -e "   from:$ePF $AR_OUT/package_esp32_index.template.json $eNO"
echo -e "   to:$ePF $ESP32_ARDUINO/package/package_esp32_index.template.json $eNO"
# Remove the old package_esp32_index.template.json
rm -rf $ESP32_ARDUINO/package/package_esp32_index.template.json
# Take care that the folder exists
mkdir -p $ESP32_ARDUINO/package
# Copy
cp -f $AR_OUT/package_esp32_index.template.json $ESP32_ARDUINO/package/package_esp32_index.template.json

# Copy the Tools to the Arduino folder
# ---------------------------------------
echo -e "   Installing new Tools, try to copy..."
echo -e "   from:$ePF $AR_TOOLS/esp32-arduino-libs $eNO"
echo -e "   to:$ePF $ESP32_ARDUINO/tools/ $eNO"
# Remove the old esp32-arduino-libs
rm -rf $ESP32_ARDUINO/tools/esp32-arduino-libs 
# Take care that the folder exists
mkdir -p $ESP32_ARDUINO/tools/
# Copy
cp -Rf $AR_TOOLS/esp32-arduino-libs $ESP32_ARDUINO/tools/
