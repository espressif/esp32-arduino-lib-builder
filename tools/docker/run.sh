#!/usr/bin/env bash

i=0
NEXT_ARG="false"
ARDUINO_DIR=""
DOCKER_ARGS=()
ORIGINAL_ARGS=("$@")
TRIMMED_ARGS=()

while [ $i -lt ${#ORIGINAL_ARGS[@]} ]; do
	arg=${ORIGINAL_ARGS[$i]}
	if [ $arg == "-c" ]; then
		NEXT_ARG="true"
	elif [ $NEXT_ARG == "true" ]; then
		ARDUINO_DIR=$arg
		NEXT_ARG="false"
	else
		TRIMMED_ARGS+=($arg)
	fi
	i=$((i + 1))
done

if [ -n "$ARDUINO_DIR" ]; then
	if [ ! -d "$ARDUINO_DIR" ]; then
		echo "Arduino directory \"$ARDUINO_DIR\" does not exist"
		exit 1
	fi
	ARDUINO_DIR=$(echo $(cd $ARDUINO_DIR; pwd))
	DOCKER_ARGS+=(-v $ARDUINO_DIR:/arduino-esp32)
	TRIMMED_ARGS+=(-c /arduino-esp32)
fi

DOCKER_ARGS+=(-e HOST_UID=$UID)

if [ -n "$LIBBUILDER_GIT_SAFE_DIR" ]; then
	DOCKER_ARGS+=(-e LIBBUILDER_GIT_SAFE_DIR=$LIBBUILDER_GIT_SAFE_DIR)
fi

if [ "$VERBOSE_OUTPUT" -eq 1 ]; then
	echo "Arguments:"
	echo "DOCKER_ARGS = ${DOCKER_ARGS[@]}"
	echo "TRIMMED_ARGS = ${TRIMMED_ARGS[@]}"
	echo "Running: docker run ${DOCKER_ARGS[@]} lucassvaz/esp32-arduino-lib-builder ./build.sh ${TRIMMED_ARGS[@]}"
fi

docker run ${DOCKER_ARGS[@]} lucassvaz/esp32-arduino-lib-builder ./build.sh ${TRIMMED_ARGS[@]}
