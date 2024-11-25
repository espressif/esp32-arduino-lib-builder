#/bin/bash

source ./tools/config.sh

if ! [ -x "$(command -v $SED)" ]; then
  	echo "ERROR: $SED is not installed! Please install $SED first."
  	exit 1
fi

#
# CLONE ESP-IDF
#

if [ ! -d "$IDF_PATH" ]; then
	echo "ESP-IDF is not installed! Installing local copy"
	git clone $IDF_REPO_URL -b $IDF_BRANCH
	idf_was_installed="1"
fi

git -C "$IDF_PATH" fetch --all --tags

if [ "$IDF_TAG" ]; then
    git -C "$IDF_PATH" checkout "tags/$IDF_TAG"
    idf_was_installed="1"
elif [ "$IDF_COMMIT" ]; then
    git -C "$IDF_PATH" checkout "$IDF_COMMIT"
    commit_predefined="1"
fi

#
# UPDATE ESP-IDF TOOLS AND MODULES
#

if [ ! -x $idf_was_installed ] || [ ! -x $commit_predefined ]; then
	git -C $IDF_PATH submodule update --init --recursive
	$IDF_PATH/install.sh
	export IDF_COMMIT=$(git -C "$IDF_PATH" rev-parse --short HEAD)
	export IDF_BRANCH=$(git -C "$IDF_PATH" symbolic-ref --short HEAD || git -C "$IDF_PATH" tag --points-at HEAD)

	# Temporarily patch the ESP32-S2 I2C LL driver to keep the clock source
	cd $IDF_PATH
	patch -p1 -N -i $AR_PATCHES/esp32s2_i2c_ll_master_init.diff
	patch -p1 -N -i $AR_PATCHES/lwip_max_tcp_pcb.diff
	cd -
fi

#
# SETUP ESP-IDF ENV
#

source $IDF_PATH/export.sh
