#!/bin/bash

if [ ! $GITHUB_EVENT_NAME == "repository_dispatch" ]; then
    echo "Wrong event '$GITHUB_EVENT_NAME'!"
    exit 1
fi

#echo "Event: $GITHUB_EVENT_NAME, Repo: $GITHUB_REPOSITORY, Path: $GITHUB_WORKSPACE, Ref: $GITHUB_REF"

EVENT_JSON=`cat $GITHUB_EVENT_PATH`
action=`echo $EVENT_JSON | jq -r '.action'`
payload=`echo $EVENT_JSON | jq -r '.client_payload'`
branch=`echo $payload | jq -r '.branch'`
commit=`echo $payload | jq -r '.commit'`

echo "Action: $action, Branch: $branch, Commit: $commit"

if [ ! $action == "deploy" ] && [ ! $action == "build" ]; then
    echo "Bad Action $action"
    exit 1
fi

export GITHUB_EVENT_ACTION="$action"

if [ ! $commit == "" ] && [ ! $commit == "null" ]; then
    export IDF_COMMIT="$commit"
else
	commit=""
	if [ ! $branch == "" ] && [ ! $branch == "null" ]; then
	    export IDF_BRANCH="$branch"
        git checkout "$IDF_BRANCH" #local branches should match what the matrix wants to build
	fi
fi

source ./build.sh

#bash ./tools/archive-build.sh

if [ $action == "deploy" ]; then
    bash ./tools/push-to-arduino.sh $commit
fi
