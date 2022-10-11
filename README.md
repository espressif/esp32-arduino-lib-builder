# ESP32 Arduino Lib Builder [![Build Status](https://travis-ci.org/espressif/esp32-arduino-lib-builder.svg?branch=master)](https://travis-ci.org/espressif/esp32-arduino-lib-builder)

This repository contains the scripts that produce the libraries included with esp32-arduino.

Tested on Ubuntu (32 and 64 bit), Raspberry Pi and MacOS.

### Build on Ubuntu and Raspberry Pi
```bash
sudo apt-get install git wget curl libssl-dev libncurses-dev flex bison gperf python python-pip python-setuptools python-serial python-click python-cryptography python-future python-pyparsing python-pyelftools cmake ninja-build ccache jq
sudo pip install --upgrade pip
git clone https://github.com/espressif/esp32-arduino-lib-builder
cd esp32-arduino-lib-builder
./build.sh
```

### Recreate esp32-arduino libs in given version
Create version-v#.#.#.sh based on `framework-arduinoespressif32/tools/sdk/versions.txt`
```bash
./build.sh -I v4.4.2 -r -t esp32s2
```
