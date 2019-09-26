#!/bin/bash

if [ ! $GITHUB_EVENT_NAME == "schedule" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"

git checkout "$IDF_BRANCH" #local branches should match what the matrix wants to build

source ./build.sh

bash ./tools/push-to-arduino.sh
#bash ./tools/archive-build.sh
