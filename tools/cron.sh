#!/bin/bash

if [ ! "$GITHUB_EVENT_NAME" == "schedule" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

if [ -z "$TARGET" ]; then
    TARGET="all"
fi

export IDF_CCACHE_ENABLE=1

bash ./build.sh -e -t $TARGET
