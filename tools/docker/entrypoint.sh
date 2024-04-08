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

exec "$@"

if [ -d /arduino-esp32 ]; then
	echo "Fixing permissions on /arduino-esp32"
	chown -R `stat -c "%u:%g" /arduino-esp32` /arduino-esp32
fi
