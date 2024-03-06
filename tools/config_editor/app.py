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
    from textual.containers import Container
    from textual.widgets import Button, Header, Label
except ImportError:
    print("Please install the \"textual-dev\" package before running this script.")
    quit()

from targets import TargetsScreen
from editor import EditorScreen
from compile import CompileScreen

class ConfigEditorApp(App):
    # Main application class

    # Change to the root directory of the app to the root of the project
    script_path = os.path.abspath(os.path.dirname(__file__))
    root_path = os.path.abspath(os.path.join(script_path, "..", ".."))
    os.chdir(root_path)

    # Options
    option_target = None
    option_arduino_path = None
    option_arduino_branch = None
    option_idf_branch = None
    option_idf_commit = None
    option_debug_level = None

    ENABLE_COMMAND_PALETTE = False
    CSS_PATH = "style.tcss"
    SCREENS = {
        "targets": TargetsScreen(),
        "compile": CompileScreen(),
        "editor": EditorScreen(),
    }

    def update_targets(self, targets: str) -> None:
        # Callback function to update the targets after returning from the targets screen
        print("Updating targets in app, received: " + targets)
        if targets:
            self.option_target = str(targets)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "compile-button":
            print("Compile button pressed")
            self.push_screen("compile")
        elif event.button.id == "targets-button":
            print("Targets button pressed")
            self.push_screen("targets", self.update_targets)
        elif event.button.id == "options-button":
            print("Options button pressed")
            self.push_screen("editor")
        elif event.button.id == "quit-button":
            print("Quit button pressed")
            quit()

    def compose(self) -> ComposeResult:
        # Compose main menu
        yield Header()
        with Container(id="main-menu-container"):
            yield Label("ESP32 Arduino Static Libraries Configuration Editor", id="main-menu-title")
            yield Button("Compile Static Libraries", id="compile-button", classes="main-menu-button")
            yield Button("Select Targets", id="targets-button", classes="main-menu-button")
            yield Button("Change Configuration Options", id="options-button", classes="main-menu-button")
            yield Button("Quit", id="quit-button", classes="main-menu-button")

    def on_mount(self) -> None:
        # Event handler called when the app is mounted for the first time
        self.title = "Configurator"
        self.sub_title = "Main Menu"
        print("App started. Initial Options:")
        print("Target: " + str(self.option_target))
        print("Arduino Path: " + str(self.option_arduino_path))
        print("Arduino Branch: " + str(self.option_arduino_branch))
        print("IDF Branch: " + str(self.option_idf_branch))
        print("IDF Commit: " + str(self.option_idf_commit))
        print("IDF Debug Level: " + str(self.option_debug_level))

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

    parser.add_argument("-c", "--arduino-path",
                        metavar="<arduino path>",
                        type=str,
                        default=arduino_default_path(),
                        required=False,
                        help="Path to arduino-esp32 directory")

    parser.add_argument("-A", "--arduino-branch",
                        metavar="<arduino branch>",
                        type=str,
                        required=False,
                        help="Branch of the arduino-esp32 repository to be used")

    parser.add_argument("-I", "--idf-branch",
                        metavar="<IDF branch>",
                        type=str,
                        required=False,
                        help="Branch of the ESP-IDF repository to be used")

    parser.add_argument("-i", "--idf-commit",
                        metavar="<IDF commit>",
                        type=str,
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
    app.option_target = args.target
    app.option_arduino_path = args.arduino_path
    app.option_arduino_branch = args.arduino_branch
    app.option_idf_branch = args.idf_branch
    app.option_idf_commit = args.idf_commit
    app.option_debug_level = args.debug_level

    # Main function to run the app
    app.run()

if __name__ == "__main__":
    # If this script is run directly, start the app
    main()
