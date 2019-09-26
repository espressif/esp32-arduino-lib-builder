#/bin/bash

source ./tools/config.sh

cd "$AR_COMPS"

if [ ! -d "arduino" ]; then
	git clone $AR_REPO_URL arduino
fi

if [ ! -d "esp32-camera" ]; then
	git clone --depth 1 $CAMERA_REPO_URL
fi

if [ ! -d "esp-face" ]; then
	git clone --depth 1 $FACE_REPO_URL
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
