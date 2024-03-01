#!/usr/bin/env python

"""
Arduino Static Libraries Configuration Editor

This is a simple application to configure the static libraries for the ESP32 Arduino core.
It allows the user to select the targets to compile, change the configuration options and compile the libraries.

The application is built using the 'textual' library, which is a Python library for building text-based user interfaces.

The first argument to the script is the path to the Arduino core. If no argument is provided, it is assumed that the
Arduino core is located in the default path `/arduino-esp32` (docker image default).

"""

import os

try:
    from textual.app import App, ComposeResult
    from textual.containers import Container
    from textual.widgets import Button, Header, Label
except ImportError:
    print("Please install the 'textual-dev' package before running this script.")
    quit()

from targets import TargetsScreen
from editor import EditorScreen
from compile import CompileScreen

class ConfigEditorApp(App):
    # Main application class

    # Change to the root directory of the app to the root of the project
    script_path = os.path.abspath(os.path.dirname(__file__))
    root_path = os.path.abspath(os.path.join(script_path, '..', '..'))
    os.chdir(root_path)

    # Target is set to "all" by default
    target_str = "all"

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
            self.target_str = str(targets)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "compile-button":
            print("Compile button pressed")
            self.push_screen('compile')
        elif event.button.id == "targets-button":
            print("Targets button pressed")
            self.push_screen('targets', self.update_targets)
        elif event.button.id == "options-button":
            print("Options button pressed")
            self.push_screen('editor')
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
        print("App started")


def main() -> None:
    # Main function to run the app
    ConfigEditorApp().run()

if __name__ == "__main__":
    # If this script is run directly, start the app
    main()
