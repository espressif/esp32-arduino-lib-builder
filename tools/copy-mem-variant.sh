#!/bin/bash
IDF_TARGET=$1
OCT_FLASH=
OCT_PSRAM=

if [ "$2" = "y" ]; then
	OCT_FLASH="opi"
else
	OCT_FLASH="qspi"
fi

if [ "$3" = "y" ]; then
	OCT_PSRAM="opi"
else
	OCT_PSRAM="qspi"
fi

MEMCONF=$OCT_FLASH"_$OCT_PSRAM"

source ./tools/config.sh

echo "IDF_TARGET: $IDF_TARGET, MEMCONF: $MEMCONF"

# Add IDF versions to sdkconfig
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> "build/config/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> "build/config/sdkconfig.h"

# Handle Mem Variants
rm -rf "$AR_SDK/$MEMCONF"
mkdir -p "$AR_SDK/$MEMCONF/include"
mv "build/config/sdkconfig.h" "$AR_SDK/$MEMCONF/include/sdkconfig.h"
for mem_variant in `jq -c '.mem_variants_files[]' configs/builds.json`; do
	file=$(echo "$mem_variant" | jq -c '.file' | tr -d '"')
	src=$(echo "$mem_variant" | jq -c '.src' | tr -d '"')
	cp "$src" "$AR_SDK/$MEMCONF/$file"
done;
