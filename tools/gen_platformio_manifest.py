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
        "url": "https://github.com/espressif/esp32-arduino-libs",
    },
}


def convert_version(version_line):
    """A helper function that converts a custom IDF version string
    to a suitable SemVer alternative. For example:
    'release/v5.1 420ebd208a' becomes '5.1.0+sha.420ebd208a'
    """

    regex_pattern = r"^esp-idf:\s*release\/v(?P<IDF_VERSION>[\d\.]{3,5})\s*(?P<COMMIT_HASH>[0-9a-f]{5,40})"
    match = re.search(regex_pattern, version_line)
    if not match:
        sys.stderr.write(
            f"Failed to find a regex match for '{regex_pattern}' in '{version_line}'\n"
        )
        return ""

    version = match.group("IDF_VERSION")
    commit = match.group("COMMIT_HASH")

    assert version, f"Failed to parse version value from '{version_line}'"
    assert commit, f"Failed to parse commit hash value from '{version_line}'"

    if version.count(".") < 2:
        # The most basic casting to a SemVer with three digits
        version = version + ".0"

    return f"{version}+sha.{commit}"


def main(dst_dir):
    # The "version.txt" file is expected to contain IDF version in the following format
    # "esp-idf: release/v$VERSION COMMIT_HASH".
    version_file = os.path.join("version.txt")

    if not os.path.isfile(version_file):
        sys.stderr.write("Missing the 'version.txt' file.\n")
        return -1

    version_line = ""
    with open(version_file, encoding="utf8") as fp:
        for line in fp.readlines():
            if not line.startswith("esp-idf"):
                continue
            version_line = line.strip()

    if not version_line:
        sys.stderr.write("Failed to find ESP-IDF version in the 'version.txt' file!\n")
        return -1

    converted_version = convert_version(version_line)
    if not converted_version:
        sys.stderr.write(
            f"Failed to convert version '{version_line}' from version.txt\n"
        )
        return -1

    manifest_file_path = os.path.join(dst_dir, "package.json")
    with open(manifest_file_path, "w", encoding="utf8") as fp:
        MANIFEST_DATA["version"] = converted_version
        json.dump(MANIFEST_DATA, fp, indent=2)

    print(
        f"Generated PlatformIO manifest file '{manifest_file_path}' with '{converted_version}' version"
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
    args = parser.parse_args()

    sys.exit(main(args.dst_dir))
