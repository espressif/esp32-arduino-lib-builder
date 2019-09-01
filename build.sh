#!/bin/bash

if ! [ -x "$(command -v make)" ]; then
  	echo "ERROR: Make is not installed! Please install Make first."
  	exit 1
fi

#install esp-idf and gcc toolchain
source ./tools/install-esp-idf.sh

#update components from git
./tools/update-components.sh

#build and prepare libs
./tools/build-libs.sh

#bootloader
./tools/build-bootloaders.sh

#POST Build
#./tools/copy-to-arduino.sh
