import sys
import subprocess
import os

from rich.console import RenderableType

from textual import on, work
from textual.app import ComposeResult
from textual.events import ScreenResume
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Header, Static, RichLog, Button

class CompileScreen(Screen):
    # Compile screen

    # Child process running the libraries compilation
    child_process = None

    def print_output(self, renderable: RenderableType) -> None:
        # Print output to the RichLog widget
        self.query_one(RichLog).write(renderable)

    @work(name="compliation_worker", group="compilation", exclusive=True, thread=True)
    def compile_libs(self) -> None:
        # Compile the libraries

        # Get the Arduino path from the command line arguments or use the default path
        arduino_path = ""
        if len(sys.argv) > 1:
            arduino_path = sys.argv[1]
        else:
            arduino_path = "/arduino-esp32"

        label = self.query_one("#compile-title", Static)
        self.child_process = None
        target = self.app.setting_target

        if os.path.exists(arduino_path):
            print("Starting compilation process. Using Arduino path: " + arduino_path)

            print("Compiling for " + target.upper())
            if target == "all":
                command = ["./build.sh", "-c", arduino_path]
            else:
                command = ["./build.sh", "-c", arduino_path, "-t", target]
            #command.append("--help") # For testing without compiling

            label.update("Compiling for " + target.upper())
            self.print_output("======== Compiling for " + target.upper() + " ========")
            self.print_output("Running: " + " ".join(command) + "\n")
            print("Running: " + " ".join(command))
            self.child_process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
            for output in self.child_process.stdout:
                if output == '' and self.child_process.poll() is not None:
                    print("Child process finished")
                    break
                if output:
                    self.print_output(output.strip())  # Update RichLog widget with subprocess output
            self.child_process.stdout.close()
        else:
            print("Arduino path does not exist: " + arduino_path)
            self.print_output("Arduino path does not exist: " + arduino_path)

        if not self.child_process:
            print("Compilation failed for " + target.upper() + ". Invalid path to Arduino core.")
            label.update("Compilation failed for " + target.upper() + ". Invalid path to Arduino core.")
        elif self.child_process.returncode != 0:
            print("Compilation failed for " + target.upper() + ". Return code: " + str(self.child_process.returncode))
            self.print_output("Compilation failed for " + target.upper() + ". Return code: " + str(self.child_process.returncode))
            self.print_output("Error: " + self.child_process.stderr.read())
            label.update("Compilation failed for " + target.upper())
        else:
            print("Compilation successful for " + target.upper())
            label.update("Compilation successful for " + target.upper())

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if self.child_process:
            # Terminate the child process if it is running
            print("Terminating child process")
            self.child_process.terminate()
            self.child_process.wait()
        self.dismiss()

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Compile screen resumed. Clearing logs and starting compilation process")
        log = self.query_one(RichLog)
        log.clear()
        log.focus()
        self.compile_libs()

    def compose(self) -> ComposeResult:
        # Compose the compilation screen
        yield Header()
        with Container(id="compile-log-container"):
            yield RichLog(markup=True, id="compile-log")
        with Container(id="compile-status-container"):
            yield Static("Compiling for ...", id="compile-title")
            yield Button("Back", id="compile-back-button")
