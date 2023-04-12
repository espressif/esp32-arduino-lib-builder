#!/usr/bin/env python

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

if sys.version_info[0] == 3:
    unicode = lambda s: str(s)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog = 'add_sdk_json',
        description = 'Update SDK in Arduino package index')
    parser.add_argument('-j', '--pkg-json', dest='arduino_json',  required=True, help='path to package json')
    parser.add_argument('-n', '--name',     dest='tool_name',     required=True, help='name of the SDK package')
    parser.add_argument('-v', '--version',  dest='tool_version',  required=True, help='version of the new SDK')
    parser.add_argument('-u', '--url',      dest='tool_url',      required=True, help='url to the zip of the new SDK')
    parser.add_argument('-f', '--filename', dest='tool_filename', required=True, help='filename of the zip of the new SDK')
    parser.add_argument('-s', '--size',     dest='tool_size',     required=True, help='size of the zip of the new SDK')
    parser.add_argument('-c', '--sha',      dest='tool_sha',      required=True, help='sha256 of the zip of the new SDK')
    args = parser.parse_args()

    print('Destination   : {0}.'.format(args.arduino_json))
    print('Tool Name     : {0}.'.format(args.tool_name))
    print('Tool Version  : {0}.'.format(args.tool_version))
    print('Tool URL      : {0}.'.format(args.tool_url))
    print('Tool File Name: {0}.'.format(args.tool_filename))
    print('Tool Size     : {0}.'.format(args.tool_size))
    print('Tool SHA256   : {0}.'.format(args.tool_sha))

    idf_path = args.idf_path;
    arduino_json = args.arduino_json;
    tool_name = args.tool_name;
    tool_version = args.tool_version;
    tool_url = args.tool_url;
    tool_filename = args.tool_filename;
    tool_size = args.tool_size;
    tool_sha = args.tool_sha;

    # code start
    farray = {"packages":[{"platforms":[{"toolsDependencies":[]}],"tools":[]}]}
    if os.path.isfile(arduino_json) == True:
        farray = json.load(open(arduino_json))

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
            break

    if dep_skip == False:
        if dep_found == False:
            print('Adding new dependency: {0} version {1}'.format(tool_name, tool_version))
            deps = {
                "packager": "esp32",
                "name": tool_name,
                "version": tool_version
            }
            farray['packages'][0]['platforms'][0]['toolsDependencies'].append(deps)

        systems = []
        system = {
            "host": '',
            "url": tool_url,
            "archiveFileName": tool_filename,
            "checksum": "SHA-256:"+tool_sha,
            "size": str(tool_size)
        }

        system["host"] = "i686-mingw32";
        systems.append(system)
        system["host"] = "x86_64-mingw32";
        systems.append(system)
        system["host"] = "arm64-apple-darwin";
        systems.append(system)
        system["host"] = "x86_64-apple-darwin";
        systems.append(system)
        system["host"] = "x86_64-pc-linux-gnu";
        systems.append(system)
        system["host"] = "i686-pc-linux-gnu";
        systems.append(system)
        system["host"] = "aarch64-linux-gnu";
        systems.append(system)
        system["host"] = "arm-linux-gnueabihf";
        systems.append(system)

        tool_found = False
        for t in farray['packages'][0]['tools']:
            if t['name'] == tool_name:
                t['version'] = tool_version
                t['systems'] = systems
                tool_found = True
                print('Updating systems of {0} to version {1}'.format(tool_name, tool_version))
                break

        if tool_found == False:
            print('Adding new tool: {0} version {1}'.format(tool_name, tool_version))
            tools = {
                "name": tool_name,
                "version": tool_version,
                "systems": systems
            }
            farray['packages'][0]['tools'].append(tools)

        json_str = json.dumps(farray, indent=2)
        with open(arduino_json, "w") as f:
            f.write(json_str+"\n")
            f.close()
        # print(json_str)
        print('{0} generated'.format(arduino_json))
