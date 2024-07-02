#!/bin/bash

set -e

if [ ! $# -eq 2 ]; then
	echo "Bad number of arguments: $#" >&2
	echo "Usage: $0 <branches> <targets>" >&2
	exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
    echo "ERROR: jq is not installed! Please install jq first."
    exit 1
fi

if ! [ -x "$(command -v sed)" ]; then
    echo "ERROR: sed is not installed! Please install sed first."
    exit 1
fi

echo "Inputs:"
echo "idf_branch: $1"
echo "target: $2"

# Change this based on the IDF branches we want to build
all_branches="[\"release/v5.1\"]"

# Change this based on the COMMON targets for all branches we want to build.
common_targets="[\"esp32\", \"esp32s2\", \"esp32s3\", \"esp32c2\", \"esp32c3\", \"esp32c6\", \"esp32h2\"]"

# For additional targets per branch, add them here
additional_targets="[{\"idf_branch\": \"release/v5.3\", \"target\": \"esp32p4\"}]"

if [ -z "$1" ] || [ "$1" == "all" ]; then
    branches=$all_branches
else
    branches=$(echo "$1" | sed 's/ *, */,/g' | sed 's/^/["/' | sed 's/$/"]/' | sed 's/,/","/g')
fi

if [ -z "$2" ] || [ "$2" == "all" ]; then
    targets="all"
else
    targets=$(echo "$2" | sed 's/ *, */,/g' | sed 's/^/["/' | sed 's/$/"]/' | sed 's/,/","/g')
fi

matrix="{"
matrix+="\"idf_branch\": $branches,"

if [ "$targets" == "all" ]; then
    matrix+="\"target\": $common_targets,"
    matrix+="\"include\": "
    # Add all additional targets that are in the selected branches
    matrix+=$(echo $additional_targets | jq --argjson branches "$branches" '[.[] | select(.idf_branch as $branch | $branches | index($branch))]')
else
    matrix+="\"target\": $targets"
fi

matrix+="}"

echo "Matrix:"
echo "$matrix" | jq .

if [ ! -x $GITHUB_OUTPUT ]; then
    echo "matrix=$matrix" >> $GITHUB_OUTPUT
    echo "branches=$branches" >> $GITHUB_OUTPUT
fi
