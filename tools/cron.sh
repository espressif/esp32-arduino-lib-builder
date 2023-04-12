#!/bin/bash

if [ ! "$GITHUB_EVENT_NAME" == "schedule" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

git checkout "$IDF_BRANCH" #local branches should match what the matrix wants to build
DEPLOY_OUT=1
source ./build.sh
# bash ./tools/push-to-arduino.sh
