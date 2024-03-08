from textual import on
from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import Header, Button, Switch, Label

from widgets import LabelledInput, LabelledSelect

class SettingsScreen(Screen):
    # Settings screen

    target_select: LabelledSelect
    enable_copy_switch: Switch
    arduino_path_input: LabelledInput
    arduino_branch_input: LabelledInput
    idf_branch_input: LabelledInput
    idf_commit_input: LabelledInput
    idf_debug_select: LabelledSelect

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "save-settings-button":
            print("Save button pressed")

            self.app.setting_target = self.target_select.get_select_value()
            print("Target setting updated: " + self.app.setting_target)

            self.app.setting_enable_copy = self.enable_copy_switch.value
            print("Enable copy setting updated: " + str(self.app.setting_enable_copy))

            if self.enable_copy_switch.value:
                self.app.setting_arduino_path = self.arduino_path_input.get_input_value()
                print("Arduino path setting updated: " + self.app.setting_arduino_path)

            self.app.setting_arduino_branch = self.arduino_branch_input.get_input_value()
            print("Arduino branch setting updated: " + self.app.setting_arduino_branch)

            self.app.setting_idf_branch = self.idf_branch_input.get_input_value()
            print("IDF branch setting updated: " + self.app.setting_idf_branch)

            self.app.setting_idf_commit = self.idf_commit_input.get_input_value()
            print("IDF commit setting updated: " + self.app.setting_idf_commit)

            self.app.setting_debug_level = self.idf_debug_select.get_select_value()
            print("Debug level setting updated: " + self.app.setting_debug_level)

            self.dismiss()
        elif event.button.id == "cancel-settings-button":
            print("Cancel button pressed")
            self.dismiss()

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Settings screen resumed. Updating settings.")
        self.target_select.set_select_value(self.app.setting_target)
        self.enable_copy_switch.value = self.app.setting_enable_copy
        self.arduino_path_input.set_input_value(self.app.setting_arduino_path)
        self.arduino_branch_input.set_input_value(self.app.setting_arduino_branch)
        self.idf_branch_input.set_input_value(self.app.setting_idf_branch)
        self.idf_commit_input.set_input_value(self.app.setting_idf_commit)
        self.idf_debug_select.set_select_value(self.app.setting_debug_level)

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
            self.target_select = LabelledSelect("Compilation Target", target_options, allow_blank=False, id="target-select")
            yield self.target_select

            with Horizontal(classes="settings-switch-container"):
                self.enable_copy_switch = Switch(value=self.app.setting_enable_copy, id="enable-copy-switch")
                yield self.enable_copy_switch

                yield Label("Copy to arduino-esp32 after compilation")

            self.arduino_path_input = LabelledInput("Arduino-esp32 Path", placeholder="Path to your arduino-esp32 installation", value=self.app.setting_arduino_path, id="arduino-path-input")
            yield self.arduino_path_input

            self.arduino_branch_input = LabelledInput("Arduino-esp32 Branch", placeholder="Leave empty to use default", value=self.app.setting_arduino_branch, id="arduino-branch-input")
            yield self.arduino_branch_input

            self.idf_branch_input = LabelledInput("ESP-IDF Branch", placeholder="Leave empty to use default", value=self.app.setting_idf_branch, id="idf-branch-input")
            yield self.idf_branch_input

            self.idf_commit_input = LabelledInput("ESP-IDF Commit", placeholder="Leave empty to use default", value=self.app.setting_idf_commit, id="idf-commit-input")
            yield self.idf_commit_input

            debug_options = [
                ("Default", "default"),
                ("None", "none"),
                ("Error", "error"),
                ("Warning", "warning"),
                ("Info", "info"),
                ("Debug", "debug"),
                ("Verbose", "verbose")
            ]
            self.idf_debug_select = LabelledSelect("ESP-IDF Debug Level", debug_options, allow_blank=False, id="idf-debug-select")
            yield self.idf_debug_select

        with Horizontal(id="settings-button-container"):
            yield Button("Save", id="save-settings-button", classes="settings-button")
            yield Button("Cancel", id="cancel-settings-button", classes="settings-button")

    def on_mount(self) -> None:
        # Event handler called when the screen is mounted for the first time
        self.sub_title = "Settings"
        print("Settings screen mounted")
