#!/usr/bin/env bash

# This is an example of how to run the docker container.
# This script is not part of the container, it is meant to be run on the host machine.
# Note that this file will build the release/v5.3 branch. For other branches, change the tag accordingly.
# You can check the available tags at https://hub.docker.com/r/espressif/esp32-arduino-lib-builder/tags
# Usage: ./run.sh <path_to_arduino_esp32>

if ! [ -x "$(command -v docker)" ]; then
	echo "ERROR: Docker is not installed! Please install docker first."
	exit 1
fi

if [ -n "$1" ]; then
    ARDUINO_DIR=$(realpath "$1")
else
    ARDUINO_DIR=""
fi

DOCKER_ARGS=()

DOCKER_ARGS+=(-it)
DOCKER_ARGS+=(-e TERM=xterm-256color)

if [ -d "$ARDUINO_DIR" ]; then
	DOCKER_ARGS+=(-v $ARDUINO_DIR:/arduino-esp32)
else
	echo "Warning: Invalid arduino directory: '$ARDUINO_DIR'. Ignoring it."
fi

if [ -n "$LIBBUILDER_GIT_SAFE_DIR" ]; then
	DOCKER_ARGS+=(-e LIBBUILDER_GIT_SAFE_DIR=$LIBBUILDER_GIT_SAFE_DIR)
fi

echo "Running: docker run ${DOCKER_ARGS[@]} espressif/esp32-arduino-lib-builder"
docker run ${DOCKER_ARGS[@]} espressif/esp32-arduino-lib-builder:release-v5.3
