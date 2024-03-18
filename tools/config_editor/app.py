#!/usr/bin/env python

"""
Arduino Static Libraries Configuration Editor

This is a simple application to configure the static libraries for the ESP32 Arduino core.
It allows the user to select the targets to compile, change the configuration options and compile the libraries.

Requires Python 3.9 or later.

The application is built using the "textual" library, which is a Python library for building text-based user interfaces.

Note that this application still needs the requirements from esp32-arduino-lib-builder to be installed.

Command line arguments:
    -t, --target <target>          Target to be compiled. Choose from: all, esp32, esp32s2, esp32s3, esp32c2, esp32c3, esp32c6, esp32h2. Default: all
    --copy, --no-copy              Enable/disable copying the compiled libraries to arduino-esp32. Enabled by default
    -c, --arduino-path <path>      Path to arduino-esp32 directory. Default: OS dependent
    -A, --arduino-branch <branch>  Branch of the arduino-esp32 repository to be used. Default: set by the build script
    -I, --idf-branch <branch>      Branch of the ESP-IDF repository to be used. Default: set by the build script
    -i, --idf-commit <commit>      Commit of the ESP-IDF repository to be used. Default: set by the build script
    -D, --debug-level <level>      Debug level to be set to ESP-IDF. Choose from: default, none, error, warning, info, debug, verbose. Default: default

"""

import argparse
import os
import platform
import sys

from pathlib import Path

try:
    from textual.app import App, ComposeResult
    from textual.binding import Binding
    from textual.containers import VerticalScroll
    from textual.screen import Screen
    from textual.widgets import Button, Header, Label, Footer
except ImportError:
    print("Please install the \"textual\" package before running this script.")
    exit(1)

from settings import SettingsScreen
from editor import EditorScreen
from compile import CompileScreen

class MainScreen(Screen):
    # Main screen class

    # Set the key bindings
    BINDINGS = [
        Binding("c", "app.push_screen('compile')", "Compile"),
        Binding("e", "app.push_screen('editor')", "Editor"),
        Binding("s", "app.push_screen('settings')", "Settings"),
        Binding("q", "app.quit", "Quit"),
    ]

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "compile-button":
            print("Compile button pressed")
            self.app.push_screen("compile")
        elif event.button.id == "settings-button":
            print("Settings button pressed")
            self.app.push_screen("settings")
        elif event.button.id == "editor-button":
            print("Editor button pressed")
            self.app.push_screen("editor")
        elif event.button.id == "quit-button":
            print("Quit button pressed")
            self.app.exit()

    def compose(self) -> ComposeResult:
        # Compose main menu
        yield Header()
        with VerticalScroll(id="main-menu-container"):
            yield Label("ESP32 Arduino Static Libraries Configuration Editor", id="main-menu-title")
            yield Button("Compile Static Libraries", id="compile-button", classes="main-menu-button")
            yield Button("Sdkconfig Editor", id="editor-button", classes="main-menu-button")
            yield Button("Settings", id="settings-button", classes="main-menu-button")
            yield Button("Quit", id="quit-button", classes="main-menu-button")
        yield Footer()

    def on_mount(self) -> None:
        # Event handler called when the app is mounted for the first time
        self.title = "Configurator"
        self.sub_title = "Main Menu"
        print("Main screen mounted.")

class ConfigEditorApp(App):
    # Main application class

    # Set the root and script paths
    SCRIPT_PATH = os.path.abspath(os.path.dirname(__file__))
    ROOT_PATH = os.path.abspath(os.path.join(SCRIPT_PATH, "..", ".."))

    # Set the application options
    setting_enable_copy = True

    # Options to be set by the command line arguments
    setting_target = ""
    setting_arduino_path = ""
    setting_arduino_branch = ""
    setting_idf_branch = ""
    setting_idf_commit = ""
    setting_debug_level = ""

    ENABLE_COMMAND_PALETTE = False
    CSS_PATH = "style.tcss"
    SCREENS = {
        "main": MainScreen(),
        "settings": SettingsScreen(),
        "compile": CompileScreen(),
        "editor": EditorScreen(),
    }

    def on_mount(self) -> None:
        print("Application mounted. Initial options:")
        print("Python version: " + sys.version)
        print("Root path: " + self.ROOT_PATH)
        print("Script path: " + self.SCRIPT_PATH)
        print("Target: " + str(self.setting_target))
        print("Enable Copy: " + str(self.setting_enable_copy))
        print("Arduino Path: " + str(self.setting_arduino_path))
        print("Arduino Branch: " + str(self.setting_arduino_branch))
        print("IDF Branch: " + str(self.setting_idf_branch))
        print("IDF Commit: " + str(self.setting_idf_commit))
        print("IDF Debug Level: " + str(self.setting_debug_level))
        self.push_screen("main")

def arduino_default_path():
    sys_name = platform.system()
    home = str(Path.home())
    if sys_name == "Linux":
        return os.path.join(home, "Arduino", "hardware", "espressif", "esp32")
    else: # Windows and MacOS
        return os.path.join(home, "Documents", "Arduino", "hardware", "espressif", "esp32")

def main() -> None:
    # Set the PYTHONUNBUFFERED environment variable to "1" to disable the output buffering
    os.environ['PYTHONUNBUFFERED'] = "1"

    # Check Python version
    if sys.version_info < (3, 9):
        print("This script requires Python 3.9 or later")
        exit(1)

    app = ConfigEditorApp()

    parser = argparse.ArgumentParser(description="Configure and compile the ESP32 Arduino static libraries")

    target_choices = ("all", "esp32", "esp32s2", "esp32s3", "esp32c2", "esp32c3", "esp32c6", "esp32h2")
    parser.add_argument("-t", "--target",
                        metavar="<target>",
                        type=str,
                        default="all",
                        choices=target_choices,
                        required=False,
                        help="Target to be compiled. Choose from: " + ", ".join(target_choices))

    parser.add_argument("--copy",
                        type=bool,
                        action=argparse.BooleanOptionalAction,
                        default=True,
                        required=False,
                        help="Enable/disable copying the compiled libraries to arduino-esp32. Enabled by default")

    parser.add_argument("-c", "--arduino-path",
                        metavar="<arduino path>",
                        type=str,
                        default=arduino_default_path(),
                        required=False,
                        help="Path to arduino-esp32 directory. Default: " + arduino_default_path())

    parser.add_argument("-A", "--arduino-branch",
                        metavar="<arduino branch>",
                        type=str,
                        default="",
                        required=False,
                        help="Branch of the arduino-esp32 repository to be used")

    parser.add_argument("-I", "--idf-branch",
                        metavar="<IDF branch>",
                        type=str,
                        default="",
                        required=False,
                        help="Branch of the ESP-IDF repository to be used")

    parser.add_argument("-i", "--idf-commit",
                        metavar="<IDF commit>",
                        type=str,
                        default="",
                        required=False,
                        help="Commit of the ESP-IDF repository to be used")

    debug_level_choices = ("default", "none", "error", "warning", "info", "debug", "verbose")
    parser.add_argument("-D", "--debug-level",
                        metavar="<level>",
                        type=str,
                        default="default",
                        choices=debug_level_choices,
                        required=False,
                        help="Debug level to be set to ESP-IDF. Choose from: " + ", ".join(debug_level_choices))

    args = parser.parse_args()

    # Set the options in the app
    app.setting_target = args.target
    app.setting_enable_copy = args.copy
    app.setting_arduino_path = os.path.abspath(args.arduino_path)
    app.setting_arduino_branch = args.arduino_branch
    app.setting_idf_branch = args.idf_branch
    app.setting_idf_commit = args.idf_commit
    app.setting_debug_level = args.debug_level

    # Change to the root directory of the app to the root of the project
    os.chdir(app.ROOT_PATH)

    # Main function to run the app
    app.run()

    # Propagate the exit code from the app
    exit(app.return_code or 0)

if __name__ == "__main__":
    # If this script is run directly, start the app
    main()
