#!/usr/bin/env bash

ARDUINO_DIR=${1:-$PWD/../}
DOCKER_ARGS=()

ARDUINO_DIR=$(echo $(cd $ARDUINO_DIR; pwd))
DOCKER_ARGS+=(-it)
DOCKER_ARGS+=(-v $ARDUINO_DIR:/arduino-esp32)
DOCKER_ARGS+=(-e TERM=xterm-256color)
DOCKER_ARGS+=(-e HOST_UID=$UID)

if [ -n "$LIBBUILDER_GIT_SAFE_DIR" ]; then
	DOCKER_ARGS+=(-e LIBBUILDER_GIT_SAFE_DIR=$LIBBUILDER_GIT_SAFE_DIR)
fi

echo "Running: docker run ${DOCKER_ARGS[@]} lucassvaz/esp32-arduino-lib-builder:latest"
docker run ${DOCKER_ARGS[@]} lucassvaz/esp32-arduino-lib-builder:latest python3 tools/config_editor/app.py
