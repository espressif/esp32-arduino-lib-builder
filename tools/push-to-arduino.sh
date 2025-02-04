#!/bin/bash

source ./tools/install-arduino.sh

if [ -x $GITHUB_TOKEN ]; then
	echo "ERROR: GITHUB_TOKEN was not defined"
	exit 1
fi

# setup git for pushing
git config --global github.user "$GITHUB_ACTOR"
git config --global user.name "$GITHUB_ACTOR"
git config --global user.email "$GITHUB_ACTOR@github.com"

#
# UPDATE FILES
#

#
# esp32-arduino-libs
#

LIBS_ZIP_FILENAME="esp32-arduino-libs-$LIBS_VERSION.zip"
LIBS_JSON_FILENAME="package-$LIBS_VERSION.json"
IDF_LIBS_ZIP_URL="https://github.com/$AR_LIBS_REPO/releases/download/$LIBS_RELEASE_TAG/$LIBS_ZIP_FILENAME"
IDF_LIBS_JSON_URL="https://github.com/$AR_LIBS_REPO/releases/download/$LIBS_RELEASE_TAG/$LIBS_JSON_FILENAME"

if [ $AR_HAS_COMMIT == "0" ] || [ $LIBS_HAS_ASSET == "0" ]; then
	cd "$AR_ROOT"
	mkdir -p dist

	# check if the release exists
	if [ $LIBS_HAS_RELEASE == "0" ]; then
		echo "Release for tag \"$LIBS_RELEASE_TAG\" not found. Please create the release first."
		exit 1
	fi

	# Delete old assets for the version
	if [ $LIBS_HAS_ASSET == "1" ]; then
		echo "Deleting existing assets for version '$LIBS_VERSION'..."
		if [ `github_release_asset_delete "$AR_LIBS_REPO" "$LIBS_ASSET_ID"` == "0" ]; then
			echo "ERROR: Failed to delete asset '$LIBS_ZIP_FILENAME'"
		fi
		JSON_ASSET_ID=`github_release_asset_id "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "$LIBS_JSON_FILENAME"`
		if [ "$JSON_ASSET_ID" != "" ] && [ `github_release_asset_delete "$AR_LIBS_REPO" "$JSON_ASSET_ID"` == "0" ]; then
			echo "ERROR: Failed to delete asset '$LIBS_JSON_FILENAME'"
		fi
	fi

	sleep 5
	echo "Creating asset '$LIBS_ZIP_FILENAME'..."
	mv -f "dist/esp32-arduino-libs.zip" "dist/$LIBS_ZIP_FILENAME"

	LIBS_ASSET_ID=`github_release_asset_upload "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "$LIBS_ZIP_FILENAME" "dist/$LIBS_ZIP_FILENAME"`
	if [ -z "$LIBS_ASSET_ID" ]; then
		echo "ERROR: Failed to upload asset '$LIBS_ZIP_FILENAME. Retrying..."
		LIBS_ASSET_ID=`github_release_asset_upload "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "$LIBS_ZIP_FILENAME" "dist/$LIBS_ZIP_FILENAME"`
		if [ -z "$LIBS_ASSET_ID" ]; then
			echo "ERROR: Failed to upload asset '$LIBS_ZIP_FILENAME'"
			exit 1
		fi
	fi

	echo "Finished uploading asset '$LIBS_ZIP_FILENAME'. Asset ID: $LIBS_ASSET_ID"
	sleep 5

	# Calculate the local file checksum and size
	local_checksum=$(sha256sum "dist/$LIBS_ZIP_FILENAME" | awk '{print $1}')
	local_size=$(stat -c%s "dist/$LIBS_ZIP_FILENAME")

	echo "Downloading asset '$LIBS_ZIP_FILENAME' and checking integrity..."

	# Download the file
	remote_file="remote-$LIBS_ZIP_FILENAME"
	curl -s -L -o "$remote_file" "$IDF_LIBS_ZIP_URL"

	# Check if the download was successful
	if [ $? -ne 0 ]; then
		echo "Error downloading file from $IDF_LIBS_ZIP_URL"
		exit 1
	fi

	# Calculate the remote file checksum and size
	remote_checksum=$(sha256sum "$remote_file" | awk '{print $1}')
	remote_size=$(stat -c%s "$remote_file")

	echo "Local: $local_size bytes, $local_checksum"
	echo "Remote: $remote_size bytes, $remote_checksum"

	# Check if the checksums match
	if [ "$local_checksum" != "$remote_checksum" ]; then
		echo "Checksum mismatch for downloaded file"
		echo "Deleting asset and exiting..."
		if [ `github_release_asset_delete "$AR_LIBS_REPO" "$LIBS_ASSET_ID"` == "0" ]; then
			echo "ERROR: Failed to delete asset '$LIBS_ZIP_FILENAME'"
		fi
		exit 1
	fi

	# Clean up the downloaded file
	rm "$remote_file"

	# Print the results
	echo "Tool: esp32-arduino-libs"
	echo "Version: $LIBS_VERSION"
	echo "URL: $IDF_LIBS_ZIP_URL"
	echo "File: $LIBS_ZIP_FILENAME"
	echo "Size: $local_size bytes"
	echo "SHA-256: $local_checksum"
	echo "JSON: $AR_OUT/package_esp32_index.template.json"
	cd "$AR_ROOT"
	python3 tools/add_sdk_json.py -j "$AR_OUT/package_esp32_index.template.json" -n "esp32-arduino-libs" -v "$LIBS_VERSION" -u "$IDF_LIBS_ZIP_URL" -f "$LIBS_ZIP_FILENAME" -s "$local_size" -c "$local_checksum"
	if [ $? -ne 0 ]; then exit 1; fi

	JSON_ASSET_ID=`github_release_asset_upload "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "$LIBS_JSON_FILENAME" "$AR_OUT/package_esp32_index.template.json"`
	if [ -z "$JSON_ASSET_ID" ]; then
		echo "ERROR: Failed to upload asset '$LIBS_JSON_FILENAME'. Retrying..."
		JSON_ASSET_ID=`github_release_asset_upload "$AR_LIBS_REPO" "$LIBS_RELEASE_ID" "$LIBS_JSON_FILENAME" "$AR_OUT/package_esp32_index.template.json"`
		if [ -z "$JSON_ASSET_ID" ]; then
			echo "ERROR: Failed to upload asset '$LIBS_JSON_FILENAME'"
			exit 1
		fi
	fi
fi

#
# esp32-arduino
#

if [ $AR_HAS_COMMIT == "0" ] || [ $LIBS_HAS_ASSET == "0" ]; then
	cd "$AR_ROOT"
	# create or checkout the branch
	if [ ! $AR_HAS_BRANCH == "0" ]; then
		echo "Switching to arduino branch '$AR_NEW_BRANCH_NAME'..."
		git -C "$AR_COMPS/arduino" checkout $AR_NEW_BRANCH_NAME
	else
		echo "Creating arduino branch '$AR_NEW_BRANCH_NAME'..."
		git -C "$AR_COMPS/arduino" checkout -b $AR_NEW_BRANCH_NAME
	fi
	if [ $? -ne 0 ]; then
		echo "ERROR: Checkout of branch '$AR_NEW_BRANCH_NAME' failed"
		exit 1
	fi

	# make changes to the files
	echo "Patching files in branch '$AR_NEW_BRANCH_NAME'..."
	rm -rf "$AR_COMPS/arduino/package/package_esp32_index.template.json" && cp -f "$AR_OUT/package_esp32_index.template.json" "$AR_COMPS/arduino/package/package_esp32_index.template.json"

	cd $AR_COMPS/arduino

	# did any of the files change?
	if [ -n "$(git status --porcelain)" ]; then
		echo "Pushing changes to branch '$AR_NEW_BRANCH_NAME'..."
		git add . && git commit --message "$AR_NEW_COMMIT_MESSAGE" && git push -u origin $AR_NEW_BRANCH_NAME
		if [ $? -ne 0 ]; then
			echo "ERROR: Pushing to branch '$AR_NEW_BRANCH_NAME' failed"
			exit 1
		fi
	else
		echo "No changes in branch '$AR_NEW_BRANCH_NAME'"
		if [ $AR_HAS_BRANCH == "0" ]; then
			echo "Delete created branch '$AR_NEW_BRANCH_NAME'"
			git branch -d $AR_NEW_BRANCH_NAME
		fi
		exit 0
	fi

	# CREATE PULL REQUEST
	if [ "$AR_HAS_PR" == "0" ]; then
		echo "Creating PR '$AR_NEW_PR_TITLE'..."
		pr_created=`git_create_pr "$AR_NEW_BRANCH_NAME" "$AR_NEW_PR_TITLE" "$AR_PR_TARGET_BRANCH"`
		if [ $pr_created == "0" ]; then
			echo "ERROR: Failed to create PR '$AR_NEW_PR_TITLE': "`echo "$git_create_pr_res" | jq -r '.message'`": "`echo "$git_create_pr_res" | jq -r '.errors[].message'`
			exit 1
		fi
	else
		echo "PR '$AR_NEW_PR_TITLE' Already Exists"
	fi
fi

exit 0
