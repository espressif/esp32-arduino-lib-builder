#!/bin/bash

rm -rf /Users/thomas/esp/arduino-esp32
mkdir /Users/thomas/esp/arduino-esp32

#./build.sh -t 'esp32h2,esp32s2,esp32c2,esp32' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V

./build.sh -t 'esp32h2' -A 'idf-release/v5.1' -I 'release/v5.1' -e -D 'error' -c '/Users/thomas/esp/arduino-esp32' -S -V
