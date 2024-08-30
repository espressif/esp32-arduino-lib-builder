# Arduino Static Libraries Configuration Editor

This is a simple application to configure the static libraries for the ESP32 Arduino core.
It allows the user to select the targets to compile, change the configuration options and compile the libraries.
It has mouse support and can be pre-configured using command line arguments.

## Requirements
  - Python 3.9 or later
  - Install the required packages using `pip install -r requirements.txt`
  - The requirements from esp32-arduino-lib-builder

## Troubleshooting

In some cases, the UI might not look as expected. This can happen due to the terminal emulator not supporting the required features.

### WSL

If you are using WSL, it is recommended to use the Windows Terminal to visualize the application. Otherwise, the application layout and colors might not be displayed correctly.
The Windows Terminal can be installed from the Microsoft Store.

### MacOS

If you are using MacOS and the application looks weird, check [this guide from Textual](https://textual.textualize.io/FAQ/#why-doesnt-textual-look-good-on-macos) to fix it.

## Usage

These command line arguments can be used to pre-configure the application:

```
Command line arguments:
    -t, --target <target>          Comma-separated list of targets to be compiled.
                                   Choose from: all, esp32, esp32s2, esp32s3, esp32c2, esp32c3, esp32c6, esp32h2. Default: all except esp32c2
    --copy, --no-copy              Enable/disable copying the compiled libraries to arduino-esp32. Enabled by default
    -c, --arduino-path <path>      Path to arduino-esp32 directory. Default: OS dependent
    -A, --arduino-branch <branch>  Branch of the arduino-esp32 repository to be used. Default: set by the build script
    -I, --idf-branch <branch>      Branch of the ESP-IDF repository to be used. Default: set by the build script
    -i, --idf-commit <commit>      Commit of the ESP-IDF repository to be used. Default: set by the build script
    -D, --debug-level <level>      Debug level to be set to ESP-IDF.
                                   Choose from: default, none, error, warning, info, debug, verbose. Default: default
```
