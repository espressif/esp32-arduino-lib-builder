import sys
import subprocess

from rich.console import RenderableType

from textual import on
from textual.app import ComposeResult
from textual.events import ScreenResume
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Header, Static, RichLog, ProgressBar, LoadingIndicator, Button

class CompileScreen(Screen):
    """Compile screen."""

    child_process = None

    def print_output(self, renderable: RenderableType) -> None:
        self.query_one(RichLog).write(renderable)

    def compile_libs(self) -> None:
        print("Starting compilation process")

        arduino_path = ""

        if len(sys.argv) > 1:
            #Custom Arduino path
            arduino_path = sys.argv[1]
        else:
            #Default Arduino path
            arduino_path = "/arduino-esp32"

        label = self.query_one("#compile-title", Static)
        self.child_process = None
        target = self.app.target_str

        print("Compiling for " + target.upper())
        if target == "all":
            command = ["./build.sh", "-c", arduino_path]
        else:
            command = ["./build.sh", "-c", arduino_path, "-t", target]
        command.append("--help")
        label.update("Compiling for " + target.upper())
        self.print_output("======== Compiling for " + target.upper() + " ========")
        self.print_output("Running: " + " ".join(command) + "\n")
        self.child_process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        while True:
            output = self.child_process.stdout.readline()
            if output == '' and self.child_process.poll() is not None:
                break
            if output:
                self.print_output(output.strip())  # Update RichLog widget with subprocess output
        self.child_process.stdout.close()
        if self.child_process.returncode != 0:
            print("Compilation failed for " + target.upper())
            print("Return code: " + str(self.child_process.returncode))
            label.update("Compilation failed for " + target.upper())

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        if self.child_process:
            print("Terminating child process")
            self.child_process.terminate()
            self.child_process.wait()
        self.dismiss()

    def compose(self) -> ComposeResult:
        """Compose our UI."""
        yield Header()
        with Container(id="compile-container"):
            yield Static("Compiling for ...", id="compile-title")
            yield Button("Back", id="compile-back-button", classes="compile-button")
        with Container():
            yield RichLog(markup=True)

    @on(ScreenResume)
    def on_resume(self) -> None:
        print("Compile screen resumed")
        log = self.query_one(RichLog)
        log.clear()
        log.focus()
        self.compile_libs()
