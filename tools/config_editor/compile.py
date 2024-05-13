import sys
import subprocess
import os
import re

from rich.console import RenderableType

from textual import on, work
from textual.app import ComposeResult
from textual.binding import Binding
from textual.events import ScreenResume
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Header, Static, RichLog, Button, Footer

class CompileScreen(Screen):
    # Compile screen

    # Set the key bindings
    BINDINGS = [
        Binding("escape", "back", "Back")
    ]

    # Child process running the libraries compilation
    child_process = None

    log_widget: RichLog
    button_widget: Button

    def action_back(self) -> None:
        self.workers.cancel_all()
        if self.child_process:
            # Terminate the child process if it is running
            print("Terminating child process")
            self.child_process.terminate()
            try:
                self.child_process.stdout.close()
                self.child_process.stderr.close()
            except:
                pass
            self.child_process.wait()
        self.dismiss()

    def print_output(self, renderable: RenderableType, style=None) -> None:
        # Print output to the RichLog widget
        if style is None:
            self.log_widget.write(renderable)
        else:
            # Check the available styles at https://rich.readthedocs.io/en/stable/style.html
            self.log_widget.write("[" + str(style) + "]" + renderable)

    def print_error(self, error: str) -> None:
        # Print error to the RichLog widget
        self.log_widget.write("[b bright_red]" + error)
        self.button_widget.add_class("-error")
        #print("Error: " + error) # For debugging

    def print_success(self, message: str) -> None:
        # Print success message to the RichLog widget
        self.log_widget.write("[b bright_green]" + message)
        self.button_widget.add_class("-success")
        #print("Success: " + message) # For debugging

    def print_warning(self, message: str) -> None:
        # Print warning message to the RichLog widget
        self.log_widget.write("[b bright_yellow]" + message)
        #print("Warning: " + message) # For debugging

    def print_info(self, message: str) -> None:
        # Print info message to the RichLog widget
        self.log_widget.write("[b bright_cyan]" + message)
        #print("Info: " + message) # For debugging

    @work(name="compliation_worker", group="compilation", exclusive=True, thread=True)
    def compile_libs(self) -> None:
        # Compile the libraries
        print("Starting compilation process")

        label = self.query_one("#compile-title", Static)
        self.child_process = None

        if not self.app.setting_target:
            self.print_error("No target selected")
            label.update("No target selected")
            return
        elif self.app.setting_target == ",".join(self.app.supported_targets):
            target = "all targets"
        else:
            target = self.app.setting_target.replace(",", ", ").upper()

        label.update("Compiling for " + target)
        self.print_info("======== Compiling for " + target + " ========")

        command = ["./build.sh", "-t", self.app.setting_target, "-D", self.app.setting_debug_level]

        #command.append("--help") # For testing output without compiling

        if self.app.setting_enable_copy:
            if os.path.isdir(self.app.setting_arduino_path):
                command.extend(["-c", self.app.setting_arduino_path])
            else:
                self.print_error("Invalid path to Arduino core: " + self.app.setting_arduino_path)
                label.update("Invalid path to Arduino core")
                return

        if self.app.setting_arduino_branch:
            command.extend(["-A", self.app.setting_arduino_branch])

        if self.app.setting_idf_branch:
            command.extend(["-I", self.app.setting_idf_branch])

        if self.app.setting_idf_commit:
            command.extend(["-i", self.app.setting_idf_commit])

        self.print_info("Running: " + " ".join(command) + "\n")
        self.child_process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            for output in self.child_process.stdout:
                if output == '' and self.child_process.poll() is not None:
                    break
                if output:
                    self.print_output(output.strip())  # Update RichLog widget with subprocess output
            self.child_process.stdout.close()
        except Exception as e:
            print("Error reading child process output: " + str(e))
            print("Process might have terminated")

        if not self.child_process:
            self.print_error("Compilation failed for " + target + "Child process failed to start")
            label.update("Compilation failed for " + target + "Child process failed to start")
            return
        else:
            self.child_process.wait()

        if self.child_process.returncode != 0:
            self.print_error("Compilation failed for " + target + ". Return code: " + str(self.child_process.returncode))
            self.print_error("Errors:")
            try:
                for error in self.child_process.stderr:
                    if error:
                        self.print_error(error.strip())
                self.child_process.stderr.close()
            except Exception as e:
                print("Error reading child process errors: " + str(e))
            label.update("Compilation failed for " + target)
        else:
            if self.app.setting_output_permissions:
                regex = r"^[1-9][0-9]*:[1-9][0-9]*$"  # Regex to match the uid:gid format. Note that 0:0 (root) is not allowed
                if re.match(regex, self.app.setting_output_permissions):
                    print_info("Setting permissions to: " + self.app.setting_output_permissions)
                    chown_process = None
                    try:
                        chown_process = subprocess.run(["chown", "-R", self.app.setting_output_permissions, self.app.setting_arduino_path])
                        chown_process.wait()
                    except Exception as e:
                        print("Error changing permissions: " + str(e))

                    if chown_process and chown_process.returncode != 0:
                        self.print_error("Error changing permissions")
                        self.print_error("Please change the ownership of generated files manually")
                    else:
                        self.print_success("Permissions changed successfully")
                elif self.app.setting_output_permissions == "0:0":
                    self.print_warning("Permissions settings are set to root (0:0)")
                    self.print_warning("Please change the ownership of generated files manually")
                    self.print_warning("If you are compiling for Windows, you may ignore this warning")
                else:
                    self.print_error("Invalid permissions format: " + self.app.setting_output_permissions)
                    self.print_error("Please change the ownership of generated files manually")

            self.print_success("Compilation successful for " + target)
            label.update("Compilation successful for " + target)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        self.action_back()

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Compile screen resumed. Clearing logs and starting compilation process")
        self.button_widget.remove_class("-error")
        self.button_widget.remove_class("-success")
        self.log_widget.clear()
        self.log_widget.focus()
        self.compile_libs()

    def compose(self) -> ComposeResult:
        # Compose the compilation screen
        yield Header()
        with Container(id="compile-log-container"):
            self.log_widget = RichLog(markup=True, id="compile-log")
            yield self.log_widget
        with Container(id="compile-status-container"):
            yield Static("Compiling for ...", id="compile-title")
            self.button_widget = Button("Back", id="compile-back-button")
            yield self.button_widget
        yield Footer()

    def on_mount(self) -> None:
        # Event handler called when the screen is mounted
        print("Compile screen mounted")
        self.sub_title = "Compilation"
