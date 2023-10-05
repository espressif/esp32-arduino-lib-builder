#!/bin/bash

if [ ! "$GITHUB_EVENT_NAME" == "schedule" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

bash ./build.sh -d
