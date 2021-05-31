#!/bin/bash

if ! [ -x "$(command -v python)" ]; then
  	echo "ERROR: python is not installed! Please install python first."
  	exit 1
fi

if ! [ -x "$(command -v git)" ]; then
  	echo "ERROR: git is not installed! Please install git first."
  	exit 1
fi

mkdir -p dist

# update components from git
./tools/update-components.sh
if [ $? -ne 0 ]; then exit 1; fi

# install esp-idf and gcc toolchain
source ./tools/install-esp-idf.sh
if [ $? -ne 0 ]; then exit 1; fi

if [ -z $TARGETS ]; then
	TARGETS="esp32c3 esp32s2 esp32"
fi

echo $(git -C $AR_COMPS/arduino describe --all --long) > version.txt

rm -rf out build sdkconfig sdkconfig.old

for target in $TARGETS; do
	# configure the build for the target
	rm -rf build sdkconfig sdkconfig.old
	cp "sdkconfig.$target" sdkconfig
	# build and prepare libs
	idf.py build
	if [ $? -ne 0 ]; then exit 1; fi
	cp sdkconfig "sdkconfig.$target"
	# build bootloaders
	./tools/build-bootloaders.sh
	if [ $? -ne 0 ]; then exit 1; fi
done

# archive the build
./tools/archive-build.sh
if [ $? -ne 0 ]; then exit 1; fi

#./tools/copy-to-arduino.sh
