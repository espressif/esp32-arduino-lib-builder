# ESP32 Arduino Lib Builder

This repository is a FORK of the espressif/esp32-arduino-lib-builder and contains the scripts that produce the libraries included with esp32-arduino.

It contains modifications in the manner to ... 
* Get info in Terminal to see what is going on and what folders are created where
* Get it running on macOS

## Used in macOS Moneytary 12.7.5 (Intel) and macOS Ventura (ARM)

### Install needed tools on macOS:
* Install [Xcode](https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://apps.apple.com/us/app/xcode/id497799835%3Fmt%3D12&ved=2ahUKEwjwn4vkzqiGAxUahf0HHTb6CXQQFnoECBMQAQ&usg=AOvVaw2fEvMbfRtGhB4SPHYB54NX) as it provide the needed ***build*** cababilities
* This tools are already installed with macOS or XCode: **git**, ***flex***,  ***bison***, ***gperf*** <br/>
  - You and simply check if installed example: *git --version*
* Install [Phython for macOS](https://www.python.org/downloads)
  - Don't forget to update the Certificates with 'Install Certificates.command' after installation!
* Install with [Homebrew](https://brew.sh)
  ```bash 
  # See what already is installed 
  brew list # All
  brew list wget # Check a certain package
  # Install what is missing - ONE BY ONE!!! NOT in one line like here.. 
  brew install wget, curl, openssl, ncurses, cmake, ninja, ccache, jq, gsed, gawk, dfu-util
  ```

* Install Python-Modules with ***pip***

### Build on macOS

```bash
sudo pip install --upgrade pip
git clone https://github.com/twischi/esp32-arduino-lib-builder
cd esp32-arduino-lib-builder
./build.sh
```


### Using the User Interface

You can more easily build the libraries using the user interface found in the `tools/config_editor/` folder.
It is a Python script that allows you to select and edit the options for the libraries you want to build.
The script has mouse support and can also be pre-configured using the same command line arguments as the `build.sh` script.
For more information and troubleshooting, please refer to the [UI README](tools/config_editor/README.md).

To use it, follow these steps:

1. Make sure you have the required dependencies installed:
  - Python 3.9 or later
  - The [Textual](https://github.com/textualize/textual/) library
  - All the dependencies listed in the previous section

2. Execute the script `tools/config_editor/app.py` from any folder. It will automatically detect the path to the root of the repository.

3. Configure the compilation and ESP-IDF options as desired.

4. Click on the "Compile Static Libraries" button to start the compilation process.

5. The script will show the compilation output in a new screen. Note that the compilation process can take many hours, depending on the number of libraries selected and the options chosen.

6. If the compilation is successful and the option to copy the libraries to the Arduino Core folder is enabled, it will already be available for use in the Arduino IDE. Otherwise, you can find the compiled libraries in the `esp32-arduino-libs` folder alongside this repository.
  - Note that the copy operation doesn't currently support the core downloaded from the Arduino IDE Boards Manager, only the manual installation from the [`arduino-esp32`](https://github.com/espressif/arduino-esp32) repository.

### Documentation

For more information about how to use the Library builder, please refer to this [Documentation page](https://docs.espressif.com/projects/arduino-esp32/en/latest/lib_builder.html?highlight=lib%20builder)
