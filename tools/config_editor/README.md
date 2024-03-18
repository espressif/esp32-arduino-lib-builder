# Arduino Static Libraries Configuration Editor

This is a simple application to configure the static libraries for the ESP32 Arduino core.
It allows the user to select the targets to compile, change the configuration options and compile the libraries.

## Requirements
  - Python 3.9 or later
  - The "textual" library (install it using `pip install textual`)
  - The requirements from esp32-arduino-lib-builder

### WSL
If you are using WSL, it is recommended to use the Windows Terminal to visualize the application. Otherwise, the application layout and colors might not be displayed correctly.
The Windows Terminal can be installed from the Microsoft Store.

## Usage

Command line arguments:
    -t, --target <target>          Target to be compiled. Choose from: all, esp32, esp32s2, esp32s3, esp32c2, esp32c3, esp32c6, esp32h2
    --copy, --no-copy              Enable/disable copying the compiled libraries to arduino-esp32. Enabled by default
    -c, --arduino-path <path>      Path to arduino-esp32 directory. Default: OS dependent
    -A, --arduino-branch <branch>  Branch of the arduino-esp32 repository to be used
    -I, --idf-branch <branch>      Branch of the ESP-IDF repository to be used
    -i, --idf-commit <commit>      Commit of the ESP-IDF repository to be used
    -D, --debug-level <level>      Debug level to be set to ESP-IDF. Choose from: default, none, error, warning, info, debug, verbose
