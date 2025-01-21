import argparse
import json
import os
import re
import sys

MANIFEST_DATA = {
    "name": "framework-arduinoespressif32-libs",
    "description": "Precompiled libraries for Arduino Wiring-based Framework for the Espressif ESP32 series of SoCs",
    "keywords": ["framework", "arduino", "espressif", "esp32"],
    "license": "LGPL-2.1-or-later",
    "repository": {
        "type": "git",
        "url": "https://github.com/espressif/esp32-arduino-lib-builder",
    },
}


def convert_version(version_string):
    """A helper function that converts a custom IDF version string
    extracted from a Git repository to a suitable SemVer alternative. For example:
    'release/v5.1' becomes '5.1.0',
    'v7.7.7' becomes '7.7.7'
    """

    if version_string == 'heads/master':
        return ".".join(("5", "5", "0")) #temporary

    regex_pattern = (
        r"v(?P<MAJOR>0|[1-9]\d*)\.(?P<MINOR>0|[1-9]\d*)\.*(?P<PATCH>0|[1-9]\d*)*"
    )
    match = re.search(regex_pattern, version_string)
    if not match:
        sys.stderr.write(
            f"Failed to find a regex match for '{regex_pattern}' in '{version_string}'\n"
        )
        return ""

    major, minor, patch = match.groups()
    if not patch:
        patch = "0"

    return ".".join((major, minor, patch))


def main(dst_dir, version_string, commit_hash):

    converted_version = convert_version(version_string)
    if not converted_version:
        sys.stderr.write(f"Failed to convert version '{version_string}'\n")
        return -1

    manifest_file_path = os.path.join(dst_dir, "package.json")
    with open(manifest_file_path, "w", encoding="utf8") as fp:
        MANIFEST_DATA["version"] = f"{converted_version}+sha.{commit_hash}"
        json.dump(MANIFEST_DATA, fp, indent=2)

    print(
        f"Generated pioarduino manifest file '{manifest_file_path}' with '{converted_version}' version"
    )
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-o",
        "--dst-dir",
        dest="dst_dir",
        required=True,
        help="Destination folder where the 'package.json' manifest will be located",
    )
    parser.add_argument(
        "-s",
        "--version-string",
        dest="version_string",
        required=True,
        help="ESP-IDF version string used for compiling libraries",
    )
    parser.add_argument(
        "-c",
        "--commit-hash",
        dest="commit_hash",
        required=True,
        help="ESP-IDF revision in form of a commit hash",
    )
    args = parser.parse_args()

    sys.exit(main(args.dst_dir, args.version_string, args.commit_hash))
