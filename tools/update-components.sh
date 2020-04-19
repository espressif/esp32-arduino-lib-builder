#!/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#

if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
else
	git -C "$AR_COMPS/arduino" fetch origin && \
	git -C "$AR_COMPS/arduino" pull origin master
fi
if [ $? -ne 0 ]; then exit 1; fi
git -C "$AR_COMPS/arduino" submodule update --init --recursive

#
# CLONE/UPDATE ESP32-CAMERA
#

if [ ! -d "$AR_COMPS/esp32-camera" ]; then
	git clone $CAMERA_REPO_URL "$AR_COMPS/esp32-camera"
else
	git -C "$AR_COMPS/esp32-camera" fetch origin && \
	git -C "$AR_COMPS/esp32-camera" pull origin master
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-FACE
#

if [ ! -d "$AR_COMPS/esp-face" ]; then
	git clone $FACE_REPO_URL "$AR_COMPS/esp-face"
else
	git -C "$AR_COMPS/esp-face" fetch origin && \
	git -C "$AR_COMPS/esp-face" pull origin master
fi
if [ $? -ne 0 ]; then exit 1; fi
