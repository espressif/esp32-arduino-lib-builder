#!/bin/bash

if [ -z "$TARGET" ]; then
    TARGET="all"
fi

bash ./build.sh -e -t $TARGET
