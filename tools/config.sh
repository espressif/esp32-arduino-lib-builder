#!/bin/bash
IDF_REPO="https://github.com/espressif/esp-idf.git"
IDF_BRANCH="release/v3.2"
IDF_COMPS="$IDF_PATH/components"
IDF_TOOLCHAIN="xtensa-esp32-elf"
IDF_TOOLCHAIN_LINUX_ARMEL="https://dl.espressif.com/dl/xtensa-esp32-elf-linux-armel-1.22.0-87-gb57bad3-5.2.0.tar.gz"
IDF_TOOLCHAIN_LINUX32="https://dl.espressif.com/dl/xtensa-esp32-elf-linux32-1.22.0-80-g6c4433a-5.2.0.tar.gz"
IDF_TOOLCHAIN_LINUX64="https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-1.22.0-80-g6c4433a-5.2.0.tar.gz"
IDF_TOOLCHAIN_WIN32="https://dl.espressif.com/dl/xtensa-esp32-elf-win32-1.22.0-80-g6c4433a-5.2.0.zip"
IDF_TOOLCHAIN_MACOS="https://dl.espressif.com/dl/xtensa-esp32-elf-osx-1.22.0-80-g6c4433a-5.2.0.tar.gz"

CAMERA_REPO="https://github.com/espressif/esp32-camera.git"
FACE_REPO="https://github.com/espressif/esp-face.git"

AR_REPO="https://github.com/espressif/arduino-esp32.git"
AR_ROOT="$PWD"
AR_COMPS="$AR_ROOT/components"
AR_OUT="$AR_ROOT/out"
AR_TOOLS="$AR_OUT/tools"
AR_PLATFORM_TXT="$AR_OUT/platform.txt"
AR_PLATFORMIO_PY="$AR_TOOLS/platformio-build.py"
AR_ESPTOOL_PY="$AR_TOOLS/esptool.py"
AR_GEN_PART_PY="$AR_TOOLS/gen_esp32part.py"
AR_SDK="$AR_TOOLS/sdk"

function get_os(){
  	OSBITS=`arch`
  	if [[ "$OSTYPE" == "linux"* ]]; then
        if [[ "$OSBITS" == "i686" ]]; then
        	echo "linux32"
        elif [[ "$OSBITS" == "x86_64" ]]; then
        	echo "linux64"
        elif [[ "$OSBITS" == "armv7l" ]]; then
        	echo "linux-armel"
        else
        	echo "unknown"
	    	return 1
        fi
	elif [[ "$OSTYPE" == "darwin"* ]]; then
	    echo "macos"
	elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
	    echo "win32"
	else
	    echo "$OSTYPE"
	    return 1
	fi
	return 0
}

AR_OS=`get_os`
