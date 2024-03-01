#!/usr/bin/env python

"""
Arduino Static Libraries Configuration Editor
"""

import os

from rich.console import RenderableType

from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Button, Header, RichLog, Label

from targets import TargetsScreen
from editor import EditorScreen
from compile import CompileScreen

class ConfigEditorApp(App):
    """Textual config editor app."""

    root_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    os.chdir(root_path)

    target_dict = {
        "esp32": True,
        "esp32s2": True,
        "esp32s3": True,
        "esp32c2": True,
        "esp32c3": True,
        "esp32c6": True,
        "esp32h2": True
    }

    ENABLE_COMMAND_PALETTE = False
    CSS_PATH = "style.tcss"
    SCREENS = {
        "targets": TargetsScreen(),
        "compile": CompileScreen(),
        "editor": EditorScreen(),
    }

    def log_print(self, renderable: RenderableType) -> None:
        self.query_one(RichLog).write(renderable)

    def update_targets(self, targets: dict) -> None:
        """Update the targets dictionary."""
        self.log_print("Updating targets")
        self.log_print(targets)
        if targets:
            self.target_dict = dict(targets)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        if event.button.id == "compile-button":
            self.log_print("Compile button pressed")
            self.push_screen('compile')
        elif event.button.id == "targets-button":
            self.log_print("Targets button pressed")
            self.push_screen('targets', self.update_targets)
        elif event.button.id == "options-button":
            self.log_print("Options button pressed")
            self.push_screen('editor')
        elif event.button.id == "quit-button":
            self.log_print("Quit button pressed")
            quit()

    def compose(self) -> ComposeResult:
        """Compose our UI."""
        yield Header()
        with Container(id="main-menu-container"):
            yield Label("ESP32 Arduino Static Libraries Configuration Editor", id="main-menu-title")
            yield Button("Compile Static Libraries", id="compile-button", classes="main-menu-button")
            yield Button("Select Targets", id="targets-button", classes="main-menu-button")
            yield Button("Change Configuration Options", id="options-button", classes="main-menu-button")
            yield Button("Quit", id="quit-button", classes="main-menu-button")
            yield RichLog(classes="-hidden", wrap=False, highlight=True, markup=True)

    def on_mount(self) -> None:
        self.title = "Configurator"
        self.sub_title = "Main Menu"
        self.log_print("[b green]Welcome to the ESP32 Arduino Static Libraries Configuration Editor!")

def main() -> None:
    """Run the app."""
    ConfigEditorApp().run()

if __name__ == "__main__":
    main()

