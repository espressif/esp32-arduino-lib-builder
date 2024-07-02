#!/bin/bash

if [ -z "$TARGETS" ]; then
    TARGETS="all"
fi

export IDF_CCACHE_ENABLE=1

bash ./build.sh -e -t $TARGETS
