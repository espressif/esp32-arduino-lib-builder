#!/bin/bash

if ! [ -x "$(command -v python)" ]; then
  	echo "ERROR: python is not installed! Please install python first."
  	exit 1
fi

if ! [ -x "$(command -v git)" ]; then
  	echo "ERROR: git is not installed! Please install git first."
  	exit 1
fi

if ! [ -x "$(command -v make)" ]; then
  	echo "ERROR: Make is not installed! Please install Make first."
  	exit 1
fi

if ! [ -x "$(command -v flex)" ]; then
  	echo "ERROR: flex is not installed! Please install flex first."
  	exit 1
fi

if ! [ -x "$(command -v bison)" ]; then
  	echo "ERROR: bison is not installed! Please install bison first."
  	exit 1
fi

if ! [ -x "$(command -v gperf)" ]; then
  	echo "ERROR: gperf is not installed! Please install gperf first."
  	exit 1
fi

if ! [ -x "$(command -v stat)" ]; then
  	echo "ERROR: stat is not installed! Please install stat first."
  	exit 1
fi

mkdir -p dist

# update components from git
./tools/update-components.sh
if [ $? -ne 0 ]; then exit 1; fi

# install esp-idf and gcc toolchain
source ./tools/install-esp-idf.sh
if [ $? -ne 0 ]; then exit 1; fi

# build and prepare libs
./tools/build-libs.sh
if [ $? -ne 0 ]; then exit 1; fi

# bootloader
./tools/build-bootloaders.sh
if [ $? -ne 0 ]; then exit 1; fi

# archive the build
./tools/archive-build.sh
if [ $? -ne 0 ]; then exit 1; fi

# POST Build
#./tools/copy-to-arduino.sh
