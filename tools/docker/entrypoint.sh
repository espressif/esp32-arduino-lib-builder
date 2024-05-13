#!/usr/bin/env bash
set -e

# LIBBUILDER_GIT_SAFE_DIR has the same format as system PATH environment variable.
# All path specified in LIBBUILDER_GIT_SAFE_DIR will be added to user's
# global git config as safe.directory paths. For more information
# see git-config manual page.
if [ -n "${LIBBUILDER_GIT_SAFE_DIR+x}" ]
then
    echo "Adding following directories into git's safe.directory"
    echo "$LIBBUILDER_GIT_SAFE_DIR" | tr ':' '\n' | while read -r dir
    do
        git config --global --add safe.directory "$dir"
        echo "  $dir"
    done
fi

# Check if the mount point /arduino-esp32 exists
if [ -d "/arduino-esp32" ] && [[ "$@" == "python3 tools/config_editor/app.py"* ]]; then
    # Running UI with mount point detected, adding -c and --output-permissions arguments
    echo "Output folder permissions: `stat -c "%u:%g" /arduino-esp32`"
    exec "$@" -c /arduino-esp32 --output-permissions `stat -c "%u:%g" /arduino-esp32`
else
    # Running UI without mount point detected or running another command
    exec "$@"
fi
