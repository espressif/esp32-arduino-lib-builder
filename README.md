# ESP32 Arduino Lib Builder [![ESP32 Arduino Libs CI](https://github.com/espressif/esp32-arduino-lib-builder/actions/workflows/push.yml/badge.svg)](https://github.com/espressif/esp32-arduino-lib-builder/actions/workflows/push.yml)

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

### Using the User Interface

You can more easily build the libraries using the user interface found in the `tools/config_editor/` folder.
It is a Python script that allows you to select and edit the options for the libraries you want to build.
The script has mouse support and can also be pre-configured using the same command line arguments as the `build.sh` script.
For more information and troubleshooting, please refer to the [UI README](tools/config_editor/README.md).

To use it, follow these steps:

1. Make sure you have the following prerequisites:
  - Python 3.9 or later
  - All the dependencies listed in the previous section

2. Install the required UI packages using `pip install -r tools/config_editor/requirements.txt`.

3. Execute the script `tools/config_editor/app.py` from any folder. It will automatically detect the path to the root of the repository.

4. Configure the compilation and ESP-IDF options as desired.

5. Click on the "Compile Static Libraries" button to start the compilation process.

6. The script will show the compilation output in a new screen. Note that the compilation process can take many hours, depending on the number of libraries selected and the options chosen.

7. If the compilation is successful and the option to copy the libraries to the Arduino Core folder is enabled, it will already be available for use in the Arduino IDE. Otherwise, you can find the compiled libraries in the `esp32-arduino-libs` folder alongside this repository.
  - Note that the copy operation doesn't currently support the core downloaded from the Arduino IDE Boards Manager, only the manual installation from the [`arduino-esp32`](https://github.com/espressif/arduino-esp32) repository.

### Chip variants

Most SoCs export one folder under `esp32-arduino-libs/<target>`. ESP32-P4 also publishes `esp32p4_es` (early silicon) as a second folder. ESP32-C5 still **compiles** Matter twice (Wi-Fi vs Matter-over-Thread) but **publishes one** `esp32c5/` tree: `libespressif__esp_matter.wifi.a` and `libespressif__esp_matter.thread.a`. `configs/defconfig.esp32c5_mot` is a harvest recipe only (`harvest_only`); it is not a published `chip_variant`.

| IDF target | Published folder | Arduino IDE | Matter CHIP transport |
| --- | --- | --- | --- |
| `esp32c5` | `esp32c5` | Matter Network → Wi-Fi or Thread | Wi-Fi + CHIPoBLE, or Thread + CHIPoBLE (H2-style, Wi-Fi station off). OpenThread stays compiled for OT examples. |
| `esp32p4` | `esp32p4` | Chip Variant → v3.00 or newer | — |
| `esp32p4` | `esp32p4_es` | Chip Variant → Before v3.00 | — |

```bash
./build.sh -t esp32c5                  # Wi-Fi export, then harvest Matter-over-Thread .a into the same folder
./build.sh -t esp32c5_mot              # harvest only (fails unless esp32c5/lib already exists)
./build.sh -t esp32p4                  # P4 v3+ only
./build.sh -t esp32p4_es               # early-silicon P4 only
```

C5 is not a dual-stack Matter image. Both compiles keep `CONFIG_OPENTHREAD_ENABLED=y` and `CONFIG_OPENTHREAD_NUM_MESSAGE_BUFFERS=65`.

### Documentation

For more information about how to use the Library builder, please refer to this [Documentation page](https://docs.espressif.com/projects/arduino-esp32/en/latest/lib_builder.html?highlight=lib%20builder)
