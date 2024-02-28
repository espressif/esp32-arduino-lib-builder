from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.widgets import Footer, Header, Checkbox, Button

temp_target_dict = {
    "esp32": True,
    "esp32s2": True,
    "esp32s3": True,
    "esp32c2": True,
    "esp32c3": True,
    "esp32c6": True,
    "esp32h2": True
}

class TargetsScreen(Screen[dict]):

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        if event.button.id == "save-button":
            for checkbox in self.query("Checkbox"):
                target_text = checkbox.id[:-9]
                temp_target_dict[target_text] = checkbox.value
            self.dismiss(temp_target_dict)
        elif event.button.id == "select-all-button":
            for checkbox in self.query("Checkbox"):
                checkbox.value = True
        elif event.button.id == "select-none-button":
            for checkbox in self.query("Checkbox"):
                checkbox.value = False
        elif event.button.id == "cancel-button":
            self.dismiss({})

    def compose(self) -> ComposeResult:
        yield Header()
        with Container(id="target-selection-container"):
            with VerticalScroll(id="target-scroll-container"):
                yield Checkbox("ESP32", temp_target_dict["esp32"], classes="target-checkbox", id="esp32-checkbox")
                yield Checkbox("ESP32-S2", temp_target_dict["esp32s2"], classes="target-checkbox", id="esp32s2-checkbox")
                yield Checkbox("ESP32-S3", temp_target_dict["esp32s3"], classes="target-checkbox", id="esp32s3-checkbox")
                yield Checkbox("ESP32-C2 (ESP8684)", temp_target_dict["esp32c2"], classes="target-checkbox", id="esp32c2-checkbox")
                yield Checkbox("ESP32-C3", temp_target_dict["esp32c3"], classes="target-checkbox", id="esp32c3-checkbox")
                yield Checkbox("ESP32-C6", temp_target_dict["esp32c6"], classes="target-checkbox", id="esp32c6-checkbox")
                yield Checkbox("ESP32-H2", temp_target_dict["esp32h2"], classes="target-checkbox", id="esp32h2-checkbox")
        with Horizontal(id="target-button-container"):
            yield Button("Save", id="save-button", classes="target-button")
            yield Button("Select All", id="select-all-button", classes="target-button")
            yield Button("Select None", id="select-none-button", classes="target-button")
            yield Button("Cancel", id="cancel-button", classes="target-button")
        yield Footer()

    def on_mount(self) -> None:
        self.sub_title = "Target Selection"
        self.query_one("#esp32-checkbox", Checkbox).focus()


