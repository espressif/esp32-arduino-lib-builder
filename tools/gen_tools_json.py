#!/usr/bin/env python
# python tools/gen_tools_json.py -i $IDF_PATH -j components/arduino/package/package_esp32_index.template.json -o out/

from __future__ import print_function

__author__ = "Hristo Gochkov"
__version__ = "2023"

import os
import shutil
import errno
import os.path
import json
import platform
import sys
import stat
import argparse
import re
import requests

if sys.version_info[0] == 3:
    unicode = lambda s: str(s)

release_manifests = []

def replace_if_xz(system):
    if not system['url'].endswith(".tar.xz"):
        return system

    new_url = system['url'].replace(".tar.xz", ".tar.gz")
    new_name = system['archiveFileName'].replace(".tar.xz", ".tar.gz")
    new_signed_url = system['url'].replace(".tar.xz", "_signed.tar.gz")
    new_signed_name = system['archiveFileName'].replace(".tar.xz", "_signed.tar.gz")
    new_checksum = ""
    new_size = 0

    # let's get the checksum file from the release
    release_manifest_url = ""
    # parse the download url to extract all info needed for the checksum file url
    urlx = re.findall("^https://github.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+)/releases/download/([a-zA-Z0-9_\-.]+)/([a-zA-Z0-9_\-.]+)$", new_url)
    if urlx and len(urlx) > 0:
        (owner, proj, version, filename) = urlx[0]
        release_manifest_url = "https://github.com/%s/%s/releases/download/%s/%s-%s-checksum.sha256" % (owner, proj, version, proj, version)
    else:
        print("No manifest match")
        return system

    # check if we have already downloaded and parsed that manifest
    manifest_index = 0
    manifest_found = False
    for manifest in release_manifests:
        if manifest['url'] == release_manifest_url:
            manifest_found = True
            break
        manifest_index = manifest_index + 1

    # download and parse manifest
    if not manifest_found:
        manifest = {
            "url": release_manifest_url,
            "files": []
        }
        release_manifest_contents = requests.get(release_manifest_url).text
        x = re.findall("\s([a-zA-Z0-9_\-.]+):\s([0-9]+)\s[a-z]+\\n([a-f0-9]+)\s\*.*", release_manifest_contents)
        if x and len(x) > 0:
            for line in x:
                (filename, size, checksum) = line
                file = {
                    "name":filename,
                    "checksum":checksum,
                    "size":size
                }
                manifest["files"].append(file)
        else:
            print("No line match")
            return system

        release_manifests.append(manifest)

    # find the new file in the list and get it's size and checksum
    for file in release_manifests[manifest_index]['files']:
        if file['name'] == new_signed_name:
            print("Found a signed version of the file")
            new_url = new_signed_url
            new_name = new_signed_name
            break
    for file in release_manifests[manifest_index]['files']:
        if file['name'] == new_name:
            system['url'] = new_url
            system['archiveFileName'] = new_name
            system["checksum"] = "SHA-256:"+file['checksum']
            system["size"] = file['size']
            break
    return system

if __name__ == '__main__':

    parser = argparse.ArgumentParser(
        prog = 'gen_tools_json',
        description = 'Update Arduino package index with the tolls found in ESP-IDF')
    parser.add_argument('-i', '--esp-idf', dest='idf_path', required=True, help='Path to ESP-IDF')
    parser.add_argument('-j', '--pkg-json', dest='arduino_json', required=False, help='path to Arduino package json')
    parser.add_argument('-o', '--out-path', dest='out_path', required=True, help='Output path to store the update package json')
    args = parser.parse_args()

    simple_output = False
    if args.arduino_json == None:
        print('Source was not selected')
        simple_output = True
    else:
        print('Source {0}.'.format(args.arduino_json))

    idf_path = args.idf_path;
    arduino_json = args.arduino_json;
    out_path = args.out_path;

    # settings
    arduino_tools = ["xtensa-esp-elf","xtensa-esp-elf-gdb","riscv32-esp-elf","riscv32-esp-elf-gdb","openocd-esp32"]

    # code start
    farray = {"packages":[{"platforms":[{"toolsDependencies":[]}],"tools":[]}]}
    if simple_output == False:
        farray = json.load(open(arduino_json))

    idf_tools = json.load(open(idf_path + '/tools/tools.json'))
    for tool in idf_tools['tools']:
        try:
            tool_index = arduino_tools.index(tool['name'])
        except:
            continue
        tool_name = tool['name']
        tool_version = tool['versions'][0]['name']
        if tool_name.endswith('-elf'):
            tool_name += '-gcc'
        print('Found {0}, version: {1}'.format(tool_name, tool_version))
        
        if simple_output == False:
            dep_found = False
            dep_skip = False
            for dep in farray['packages'][0]['platforms'][0]['toolsDependencies']:
                if dep['name'] == tool_name:
                    if dep['version'] == tool_version:
                        print('Skipping {0}. Same version {1}'.format(tool_name, tool_version))
                        dep_skip = True
                        break
                    print('Updating dependency version of {0} from {1} to {2}'.format(tool_name, dep['version'], tool_version))
                    dep['version'] = tool_version
                    dep_found = True
            if dep_skip == True:
                continue
            if dep_found == False:
                print('Adding new dependency: {0} version {1}'.format(tool_name, tool_version))
                deps = {
                    "packager": "esp32",
                    "name": tool_name,
                    "version": tool_version
                }
                farray['packages'][0]['platforms'][0]['toolsDependencies'].append(deps)
        else:
            print('Adding dependency: {0} version {1}'.format(tool_name, tool_version))
            deps = {
                "packager": "esp32",
                "name": tool_name,
                "version": tool_version
            }
            farray['packages'][0]['platforms'][0]['toolsDependencies'].append(deps)

        systems = []
        for arch in tool['versions'][0]:
            if arch == 'name' or arch == 'status':
                continue
            tool_data = tool['versions'][0][arch]

            system = {
                "host": '',
                "url": tool_data['url'],
                "archiveFileName": os.path.basename(tool_data['url']),
                "checksum": "SHA-256:"+tool_data['sha256'],
                "size": str(tool_data['size'])
            }

            if arch == "win32":
                system["host"] = "i686-mingw32";
            elif arch == "win64":
                system["host"] = "x86_64-mingw32";
            elif arch == "macos-arm64":
                system["host"] = "arm64-apple-darwin";
            elif arch == "macos":
                system["host"] = "x86_64-apple-darwin";
            elif arch == "linux-amd64":
                system["host"] = "x86_64-pc-linux-gnu";
            elif arch == "linux-i686":
                system["host"] = "i686-pc-linux-gnu";
            elif arch == "linux-arm64":
                system["host"] = "aarch64-linux-gnu";
            elif arch == "linux-armel":
                system["host"] = "arm-linux-gnueabihf";
            elif arch == "linux-armhf":
                # system["host"] = "arm-linux-gnueabihf";
                continue
            else :
                continue

            system = replace_if_xz(system)

            systems.append(system)

        if simple_output == False:
            tool_found = False
            for t in farray['packages'][0]['tools']:
                if t['name'] == tool_name:
                    t['version'] = tool_version
                    t['systems'] = systems
                    tool_found = True
                    print('Updating binaries of {0} to version {1}'.format(tool_name, tool_version))
            if tool_found == False:
                print('Adding new tool: {0} version {1}'.format(tool_name, tool_version))
                tools = {
                    "name": tool_name,
                    "version": tool_version,
                    "systems": systems
                }
                farray['packages'][0]['tools'].append(tools)
        else:
            print('Adding tool: {0} version {1}'.format(tool_name, tool_version))
            tools = {
                "name": tool_name,
                "version": tool_version,
                "systems": systems
            }
            farray['packages'][0]['tools'].append(tools)

    json_str = json.dumps(farray, indent=2)
    out_file = out_path + "tools.json"
    if simple_output == False:
        out_file = out_path + os.path.basename(arduino_json)

    with open(out_file, "w") as f:
        f.write(json_str+"\n")
        f.close()
    # print(json_str)
    print('{0} generated'.format(out_file))
