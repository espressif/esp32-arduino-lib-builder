from textual import on
from textual.app import ComposeResult
from textual.containers import VerticalScroll, Container, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import Header, RadioButton, Button, RadioSet

class TargetsScreen(Screen[str]):
    temp_target_str = ""

    def update_targets(self) -> None:
        self.temp_target_str = str(self.app.target_str)
        print("Targets updated in screen")
        print(self.temp_target_str)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        if event.button.id == "save-target-button":
            for radiobutton in self.query("RadioButton"):
                target_text = radiobutton.id[:-12] # Remove "-radiobutton" from the id
                print(target_text + " " + str(radiobutton.value))
                if radiobutton.value:
                    self.temp_target_str = target_text
            self.dismiss(self.temp_target_str)
        elif event.button.id == "cancel-target-button":
            self.dismiss("")

    def compose(self) -> ComposeResult:
        yield Header()
        with VerticalScroll(id="target-scroll-container"):
            with RadioSet(id="target-radioset"):
                yield RadioButton("All", value=True, classes="target-radiobutton", id="all-radiobutton")
                yield RadioButton("ESP32", classes="target-radiobutton", id="esp32-radiobutton")
                yield RadioButton("ESP32-S2", classes="target-radiobutton", id="esp32s2-radiobutton")
                yield RadioButton("ESP32-S3", classes="target-radiobutton", id="esp32s3-radiobutton")
                yield RadioButton("ESP32-C2 (ESP8684)", classes="target-radiobutton", id="esp32c2-radiobutton")
                yield RadioButton("ESP32-C3", classes="target-radiobutton", id="esp32c3-radiobutton")
                yield RadioButton("ESP32-C6", classes="target-radiobutton", id="esp32c6-radiobutton")
                yield RadioButton("ESP32-H2", classes="target-radiobutton", id="esp32h2-radiobutton")
        with Horizontal(id="target-button-container"):
            yield Button("Save", id="save-target-button", classes="target-button")
            yield Button("Cancel", id="cancel-target-button", classes="target-button")

    def on_mount(self) -> None:
        self.sub_title = "Target Selection"
        self.query_one("#all-radiobutton", RadioButton).focus()

    @on(ScreenResume)
    def on_resume(self) -> None:
        print("Targets screen resumed")
        self.update_targets()
        for radiobutton in self.query("RadioButton"):
            target_text = radiobutton.id[:-12] # Remove "-radiobutton" from the id
            if target_text == self.temp_target_str:
                radiobutton.value = True
            else:
                radiobutton.value = False
