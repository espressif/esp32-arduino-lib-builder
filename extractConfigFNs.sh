#!/bin/bash

# Function to extract file names from semicolon-separated paths and format them
extractFileName() {
    local configs="$1"
    # Convert the semicolon-separated string into an array
    IFS=';' read -ra paths <<< "$configs"   
    # Initialize an empty array to hold file names
    local helperArray=()
    # Iterate over each path and extract the file name
    for path in "${paths[@]}"; do
        local extractedFN
        extractedFN=$(basename "$path")
        helperArray+=("$extractedFN")
    done
    local result
    # Join the file names into a semicolon-separated string
    result=$(IFS=';'; echo "${helperArray[*]}")
    # Replace semicolons with " - " for better readability
    result=${result//;/ - }
    echo "$result"
}

echo "Function 'extractFileName()' loaded successfully."