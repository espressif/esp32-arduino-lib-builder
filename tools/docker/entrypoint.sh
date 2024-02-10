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

if [ "$(id -u)" = "0" ] && [ -n "${HOST_UID}" ]; then
	groupadd -g ${HOST_UID} host_user
	useradd -m -u ${HOST_UID} -g ${HOST_UID} host_user

	if [ -d /arduino-esp32 ]; then
		chown -R ${HOST_UID}:${HOST_UID} /arduino-esp32
	fi

	chown -R ${HOST_UID}:${HOST_UID} /opt/esp

	# Add call to gosu to drop from root user to host_user
	# when running original entrypoint
	set -- gosu host_user "$@"
fi

exec "$@"
