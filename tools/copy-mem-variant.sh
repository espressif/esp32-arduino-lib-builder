#!/bin/bash
IDF_TARGET=$1
CHIP_VARIANT=$2
OCT_FLASH="$3"
OCT_PSRAM=

if [ "$4" = "y" ]; then
	OCT_PSRAM="opi"
else
	OCT_PSRAM="qspi"
fi

MEMCONF=$OCT_FLASH"_$OCT_PSRAM"

source ./tools/config.sh

echo "IDF_TARGET: $IDF_TARGET, CHIP_VARIANT: $CHIP_VARIANT, MEMCONF: $MEMCONF"

# Add IDF versions to sdkconfig (on the published copy only: build/config/sdkconfig.h
# must stay untouched so an incremental rebuild does not recompile everything).
if [ ! -f "build/config/sdkconfig.h" ]; then
	echo "ERROR: build/config/sdkconfig.h is missing; refusing to publish an incomplete sdkconfig"
	exit 1
fi
# Handle Mem Variants
rm -rf "$AR_SDK/$MEMCONF"
mkdir -p "$AR_SDK/$MEMCONF/include"
cp "build/config/sdkconfig.h" "$AR_SDK/$MEMCONF/include/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_COMMIT \"$IDF_COMMIT\"" >> "$AR_SDK/$MEMCONF/include/sdkconfig.h"
echo "#define CONFIG_ARDUINO_IDF_BRANCH \"$IDF_BRANCH\"" >> "$AR_SDK/$MEMCONF/include/sdkconfig.h"
for mem_variant in `jq -c '.mem_variants_files[]' configs/builds.json`; do
	skip_file=1
	for file_target in $(echo "$mem_variant" | jq -c '.targets[]' | tr -d '"'); do
		if [ "$file_target" == "$CHIP_VARIANT" ]; then
			skip_file=0
			break
		fi
	done
	if [ $skip_file -eq 0 ]; then
		file=$(echo "$mem_variant" | jq -c '.file' | tr -d '"')
		src=$(echo "$mem_variant" | jq -c '.src' | tr -d '"')
		cp "$src" "$AR_SDK/$MEMCONF/$file"
	fi
done;
