import math

from textual import on
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import Header, Button, Switch, Label, Footer, Checkbox

from widgets import LabelledInput, LabelledSelect

class SettingsScreen(Screen):
    # Settings screen

    # Set the key bindings
    BINDINGS = [
        Binding("s", "save", "Save"),
        Binding("escape", "app.pop_screen", "Discard")
    ]

    enable_copy_switch: Switch
    arduino_path_input: LabelledInput
    arduino_branch_input: LabelledInput
    idf_branch_input: LabelledInput
    idf_commit_input: LabelledInput
    idf_debug_select: LabelledSelect

    def action_save(self) -> None:
        checkboxes = self.query(Checkbox)
        self.app.setting_target = ""
        for checkbox in checkboxes:
            if checkbox.value:
                if self.app.setting_target:
                    self.app.setting_target += ","
                self.app.setting_target += checkbox.id.replace("-checkbox", "")
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

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "save-settings-button":
            print("Save button pressed")
            self.action_save()
        elif event.button.id == "cancel-settings-button":
            print("Cancel button pressed")
        self.dismiss()

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Settings screen resumed. Updating settings.")
        targets = self.app.setting_target.split(",")
        checkboxes = self.query(Checkbox)
        for checkbox in checkboxes:
            checkbox.value = False
            if checkbox.id.replace("-checkbox", "") in targets:
                checkbox.value = True
        self.enable_copy_switch.value = self.app.setting_enable_copy
        if self.app.setting_enable_copy:
            self.arduino_path_input.visible = True
        else:
            self.arduino_path_input.visible = False
        self.arduino_path_input.set_input_value(self.app.setting_arduino_path)
        self.arduino_branch_input.set_input_value(self.app.setting_arduino_branch)
        self.idf_branch_input.set_input_value(self.app.setting_idf_branch)
        self.idf_commit_input.set_input_value(self.app.setting_idf_commit)
        self.idf_debug_select.set_select_value(self.app.setting_debug_level)

    def on_switch_changed(self, event: Switch.Changed) -> None:
        # Event handler called when a switch is changed
        if event.switch.id == "enable-copy-switch":
            if event.switch.value:
                self.arduino_path_input.visible = True
            else:
                self.arduino_path_input.visible = False

    def compose(self) -> ComposeResult:
        # Compose the target selection screen
        yield Header()
        with VerticalScroll(id="settings-scroll-container"):

            yield Label("Compilation Targets", id="settings-target-label")
            with Container(id="settings-target-container"):
                for target in self.app.supported_targets:
                    yield Checkbox(target.upper(), id=target + "-checkbox")

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
        yield Footer()

    def on_mount(self) -> None:
        # Event handler called when the screen is mounted for the first time
        self.sub_title = "Settings"
        target_container = self.query_one("#settings-target-container")
        # Height needs to be 3 for each row of targets + 1
        height_value = str(int(math.ceil(len(self.app.supported_targets) / int(target_container.styles.grid_size_columns)) * 3 + 1))
        print("Target container height: " + height_value)
        target_container.styles.height = height_value
        print("Settings screen mounted")
