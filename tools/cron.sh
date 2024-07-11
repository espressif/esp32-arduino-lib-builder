#!/bin/bash

if [ -z "$TARGET" ]; then
    TARGET="all"
fi

export IDF_CCACHE_ENABLE=1

bash ./build.sh -e -t $TARGET
