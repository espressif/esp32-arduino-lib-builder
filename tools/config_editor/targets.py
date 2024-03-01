from textual import on
from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import Header, Checkbox, Button

class TargetsScreen(Screen[dict]):
    temp_target_dict = {}

    def update_targets(self) -> None:
        self.temp_target_dict = dict(self.app.target_dict)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        if event.button.id == "save-target-button":
            for checkbox in self.query("Checkbox"):
                target_text = checkbox.id[:-9]
                self.temp_target_dict[target_text] = checkbox.value
            self.dismiss(self.temp_target_dict)
        elif event.button.id == "select-all-button":
            for checkbox in self.query("Checkbox"):
                checkbox.value = True
        elif event.button.id == "select-none-button":
            for checkbox in self.query("Checkbox"):
                checkbox.value = False
        elif event.button.id == "cancel-target-button":
            self.dismiss({})

    def compose(self) -> ComposeResult:
        self.update_targets()
        yield Header()
        with Container(id="target-selection-container"):
            with VerticalScroll(id="target-scroll-container"):
                yield Checkbox("ESP32", True, classes="target-checkbox", id="esp32-checkbox")
                yield Checkbox("ESP32-S2", True, classes="target-checkbox", id="esp32s2-checkbox")
                yield Checkbox("ESP32-S3", True, classes="target-checkbox", id="esp32s3-checkbox")
                yield Checkbox("ESP32-C2 (ESP8684)", True, classes="target-checkbox", id="esp32c2-checkbox")
                yield Checkbox("ESP32-C3", True, classes="target-checkbox", id="esp32c3-checkbox")
                yield Checkbox("ESP32-C6", True, classes="target-checkbox", id="esp32c6-checkbox")
                yield Checkbox("ESP32-H2", True, classes="target-checkbox", id="esp32h2-checkbox")
        with Horizontal(id="target-button-container"):
            yield Button("Save", id="save-target-button", classes="target-button")
            yield Button("Select All", id="select-all-button", classes="target-button")
            yield Button("Select None", id="select-none-button", classes="target-button")
            yield Button("Cancel", id="cancel-target-button", classes="target-button")

    def on_mount(self) -> None:
        self.sub_title = "Target Selection"
        self.query_one("#esp32-checkbox", Checkbox).focus()

    @on(ScreenResume)
    def on_resume(self) -> None:
        print("Targets screen resumed")
        self.update_targets()
        print(self.temp_target_dict)
        for checkbox in self.query("Checkbox"):
            target_text = checkbox.id[:-9]
            checkbox.value = self.temp_target_dict[target_text]

