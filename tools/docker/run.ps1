# This is an example of how to run the docker container.
# This script is not part of the container, it is meant to be run on the host machine.
# Usage: ./run.ps1 <path_to_arduino_esp32>

if (-not (Test-Path -Path (Get-Command docker).Source)) {
    Write-Host "ERROR: Docker is not installed! Please install docker first."
    exit 1
}

if ($args.Count -gt 0) {
    $ARDUINO_DIR = $args[0] -replace '\\', '/'
} else {
    $ARDUINO_DIR = ''
}

$DOCKER_ARGS = @()
$DOCKER_ARGS += '-it'
$DOCKER_ARGS += '-e', 'TERM=xterm-256color'

if ((Test-Path $ARDUINO_DIR)) {
    $DOCKER_ARGS += '-v', "$ARDUINO_DIR:/arduino-esp32"
} else {
    Write-Output "Warning: Invalid arduino directory: '$ARDUINO_DIR'. Ignoring it."
}

if ($env:LIBBUILDER_GIT_SAFE_DIR) {
    $DOCKER_ARGS += '-e', "LIBBUILDER_GIT_SAFE_DIR=$env:LIBBUILDER_GIT_SAFE_DIR"
}

Write-Output "Running: docker run $($DOCKER_ARGS -join ' ') lucassvaz/esp32-arduino-lib-builder"
#docker run @($DOCKER_ARGS) lucassvaz/esp32-arduino-lib-builder
