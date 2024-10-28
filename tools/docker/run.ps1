# This is an example of how to run the docker container.
# This script is not part of the container, it is meant to be run on the host machine.
# Note that this file will build the release/v5.3 branch. For other branches, change the tag accordingly.
# You can check the available tags at https://hub.docker.com/r/espressif/esp32-arduino-lib-builder/tags
# As this script is unsigned, you may need to run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` before running it.
# Usage: .\run.ps1 <path_to_arduino_esp32>

# Exit on error
$ErrorActionPreference = "stop"

# https://devblogs.microsoft.com/scripting/use-a-powershell-function-to-see-if-a-command-exists/
# Check if command exists
Function Test-CommandExists
{
    Param ($command)
    try {
        if (Get-Command $command) {
            RETURN $true
        }
    }
    catch {
        RETURN $false
    }
}

# Check if path exists
Function Test-PathExists
{
    Param ($path)
    try {
        if (Test-Path -Path $path) {
            RETURN $true
        }
    }
    catch {
        RETURN $false
    }
}

if (-not (Test-CommandExists docker)) {
    Write-Host "ERROR: Docker is not installed! Please install docker first." -ForegroundColor red
    exit 1
}

if ($args.Count -gt 0) {
    $ARDUINO_DIR = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($args[0])
}

$DOCKER_ARGS = @()
$DOCKER_ARGS += '-it'
$DOCKER_ARGS += '-e', 'TERM=xterm-256color'

if ((Test-PathExists $ARDUINO_DIR)) {
    $DOCKER_ARGS += '-v', "${ARDUINO_DIR}:/arduino-esp32"
} else {
    Write-Output "Warning: Invalid arduino directory: '$ARDUINO_DIR'. Ignoring it."
}

if ($env:LIBBUILDER_GIT_SAFE_DIR) {
    $DOCKER_ARGS += '-e', "LIBBUILDER_GIT_SAFE_DIR=$env:LIBBUILDER_GIT_SAFE_DIR"
}

Write-Output "Running: docker run $($DOCKER_ARGS -join ' ') espressif/esp32-arduino-lib-builder"
docker run @($DOCKER_ARGS) espressif/esp32-arduino-lib-builder:release-v5.3
