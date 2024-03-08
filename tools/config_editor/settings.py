from textual import on
from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import Header, Button, Switch

from widgets import LabelledInput, LabelledSelect

class SettingsScreen(Screen):
    # Settings screen

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "save-settings-button":
            print("Save button pressed")

            # Update the target setting
            self.app.setting_target = self.query_one("#target-select", LabelledSelect).value
            print("Target setting updated: " + self.app.setting_target)

            self.dismiss()
        elif event.button.id == "cancel-settings-button":
            print("Cancel button pressed")
            self.dismiss()

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Settings screen resumed. Updating settings.")

        # Update Target selection
        self.query_one("#target-select", LabelledSelect).value = self.app.setting_target

    def compose(self) -> ComposeResult:
        # Compose the target selection screen
        yield Header()
        with VerticalScroll(id="settings-scroll-container"):
            target_options = [
                ("All", "all"),
                ("ESP32", "esp32"),
                ("ESP32-S2", "esp32s2"),
                ("ESP32-S3", "esp32s3"),
                ("ESP32-C2 (ESP8684)", "esp32c2"),
                ("ESP32-C3", "esp32c3"),
                ("ESP32-C6", "esp32c6"),
                ("ESP32-H2", "esp32h2")
            ]
            yield LabelledSelect("Compilation Target", target_options, id="target-select", classes="settings-select", allow_blank=False)
            with Horizontal(id="settings-enable-copy-container"):
                yield Switch(id="enable-copy-switch", classes="settings-switch", value=self.app.setting_enable_copy)
                yield LabelledInput("Arduino-esp32 Path", placeholder="Path to your arduino-esp32 installation", value=self.app.setting_arduino_path)
            yield LabelledInput("Arduino-esp32 Branch", placeholder="Leave empty to use default", value=self.app.setting_arduino_branch)

        with Horizontal(id="settings-button-container"):
            yield Button("Save", id="save-settings-button", classes="settings-button")
            yield Button("Cancel", id="cancel-settings-button", classes="settings-button")

    def on_mount(self) -> None:
        # Event handler called when the screen is mounted for the first time
        self.sub_title = "Settings"
        print("Settings screen mounted")
