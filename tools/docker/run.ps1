$ARDUINO_DIR = $args[0] -replace '\\', '/'
if (-not $ARDUINO_DIR) {
    $ARDUINO_DIR = (Get-Location).Path + '/../'
}

$ARDUINO_DIR = (Get-Item -Path $ARDUINO_DIR).FullName
$DOCKER_ARGS = @()
$DOCKER_ARGS += '-v', "$ARDUINO_DIR:/arduino-esp32"
$DOCKER_ARGS += '-e', 'TERM=xterm-256color'
$DOCKER_ARGS += '-e', "HOST_UID=$env:UID"

if ($env:LIBBUILDER_GIT_SAFE_DIR) {
    $DOCKER_ARGS += '-e', "LIBBUILDER_GIT_SAFE_DIR=$env:LIBBUILDER_GIT_SAFE_DIR"
}

Write-Output "Running: docker run $($DOCKER_ARGS -join ' ') lucassvaz/esp32-arduino-lib-builder:latest"
docker run @($DOCKER_ARGS) lucassvaz/esp32-arduino-lib-builder:latest python3 tools/config_editor/app.py
