#/bin/bash

source ./tools/config.sh

#
# CLONE/UPDATE ARDUINO
#

if [ ! -d "$AR_COMPS/arduino" ]; then
	git clone $AR_REPO_URL "$AR_COMPS/arduino"
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP32-CAMERA
#

if [ ! -d "$AR_COMPS/esp32-camera" ]; then
	git clone $CAMERA_REPO_URL "$AR_COMPS/esp32-camera"
fi
if [ $? -ne 0 ]; then exit 1; fi

#
# CLONE/UPDATE ESP-FACE
#

if [ ! -d "$AR_COMPS/esp-face" ]; then
	git clone $FACE_REPO_URL "$AR_COMPS/esp-face"
fi
if [ $? -ne 0 ]; then exit 1; fi
