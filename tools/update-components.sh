#/bin/bash

source ./tools/config.sh

cd "$AR_COMPS"

if [ ! -d "arduino" ]; then
	git clone $AR_REPO arduino
fi

if [ ! -d "esp32-camera" ]; then
	git clone $CAMERA_REPO
fi

if [ ! -d "esp-face" ]; then
	git clone $FACE_REPO
fi

cd "$AR_ROOT"

for component in `ls components`; do
	cd "$AR_COMPS/$component"
	if [ -d ".git" ]; then
		git fetch origin && git pull origin master
	fi
done

cd "$AR_COMPS/arduino"
git submodule update --init --recursive
cd "$AR_ROOT"
