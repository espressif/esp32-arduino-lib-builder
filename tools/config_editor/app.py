#!/usr/bin/env python

"""
Arduino Static Libraries Configuration Editor

This is a simple application to configure the static libraries for the ESP32 Arduino core.
It allows the user to select the targets to compile, change the configuration options and compile the libraries.

The application is built using the "textual" library, which is a Python library for building text-based user interfaces.

The first argument to the script is the path to the Arduino core. If no argument is provided, it is assumed that the
Arduino core is located in the default path `/arduino-esp32` (docker image default).

"""

import argparse
import os
import platform

from pathlib import Path

try:
    from textual.app import App, ComposeResult
    from textual.containers import VerticalScroll
    from textual.widgets import Button, Header, Label
except ImportError:
    print("Please install the \"textual-dev\" package before running this script.")
    quit()

from settings import SettingsScreen
from editor import EditorScreen
from compile import CompileScreen

class ConfigEditorApp(App):
    # Main application class

    # Change to the root directory of the app to the root of the project
    SCRIPT_PATH = os.path.abspath(os.path.dirname(__file__))
    ROOT_PATH = os.path.abspath(os.path.join(SCRIPT_PATH, "..", ".."))
    os.chdir(ROOT_PATH)

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
        "settings": SettingsScreen(),
        "compile": CompileScreen(),
        "editor": EditorScreen(),
    }

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "compile-button":
            print("Compile button pressed")
            self.push_screen("compile")
        elif event.button.id == "settings-button":
            print("Settings button pressed")
            self.push_screen("settings")
        elif event.button.id == "editor-button":
            print("Editor button pressed")
            self.push_screen("editor")
        elif event.button.id == "quit-button":
            print("Quit button pressed")
            quit()

    def compose(self) -> ComposeResult:
        # Compose main menu
        yield Header()
        with VerticalScroll(id="main-menu-container"):
            yield Label("ESP32 Arduino Static Libraries Configuration Editor", id="main-menu-title")
            yield Button("Compile Static Libraries", id="compile-button", classes="main-menu-button")
            yield Button("Change sdkconfig Flags", id="editor-button", classes="main-menu-button")
            yield Button("Settings", id="settings-button", classes="main-menu-button")
            yield Button("Quit", id="quit-button", classes="main-menu-button")

    def on_mount(self) -> None:
        # Event handler called when the app is mounted for the first time
        self.title = "Configurator"
        self.sub_title = "Main Menu"
        print("App started. Initial Options:")
        print("Enable Copy: " + str(self.setting_enable_copy))
        print("Target: " + str(self.setting_target))
        print("Arduino Path: " + str(self.setting_arduino_path))
        print("Arduino Branch: " + str(self.setting_arduino_branch))
        print("IDF Branch: " + str(self.setting_idf_branch))
        print("IDF Commit: " + str(self.setting_idf_commit))
        print("IDF Debug Level: " + str(self.setting_debug_level))

def arduino_default_path():
    sys_name = platform.system()
    home = str(Path.home())
    if sys_name == "Linux":
        return os.path.join(home, "Arduino", "hardware", "espressif", "esp32")
    else: # Windows and MacOS
        return os.path.join(home, "Documents", "Arduino", "hardware", "espressif", "esp32")

def main() -> None:
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
    app.setting_arduino_path = args.arduino_path
    app.setting_arduino_branch = args.arduino_branch
    app.setting_idf_branch = args.idf_branch
    app.setting_idf_commit = args.idf_commit
    app.setting_debug_level = args.debug_level

    # Main function to run the app
    app.run()

if __name__ == "__main__":
    # If this script is run directly, start the app
    main()
