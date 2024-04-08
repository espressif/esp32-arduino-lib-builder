import os

from textual import on
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Container, VerticalScroll, Horizontal
from textual.screen import Screen
from textual.events import ScreenResume
from textual.widgets import DirectoryTree, Header, TextArea, Button, Footer

class EditorScreen(Screen):
    # Configuration file editor screen

    # Set the key bindings
    BINDINGS = [
        Binding("ctrl+s", "save", "Save", priority=True),
        Binding("escape", "app.pop_screen", "Discard")
    ]

    # Current file being edited
    current_file = ""

    def action_save(self) -> None:
        code_view = self.query_one("#code", TextArea)
        current_text = code_view.text
        try:
            file = open(self.curent_file, "w")
            file.write(current_text)
            file.close()
        except Exception:
            print("Error saving file: " + self.curent_file)
            self.sub_title = "ERROR"
        else:
            print("File saved: " + self.curent_file)
            self.sub_title = self.curent_file
            self.dismiss()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        # Event handler called when a button is pressed
        if event.button.id == "save-editor-button" and self.curent_file != "":
            print("Save button pressed. Trying to save file: " + self.curent_file)
            self.action_save()
        elif event.button.id == "cancel-editor-button":
            print("Cancel button pressed")
            self.dismiss()

    def on_directory_tree_file_selected(self, event: DirectoryTree.FileSelected) -> None:
        # Called when the user click a file in the directory tree
        event.stop()
        code_view = self.query_one("#code", TextArea)
        code_view.clear()
        self.curent_file = str(event.path)
        try:
            print("Opening file: " + self.curent_file)
            file = open(self.curent_file, "r")
            file_content = file.read()
            file.close()
        except Exception:
            print("Error opening file: " + self.curent_file)
            self.sub_title = "ERROR"
        else:
            print("File opened: " + self.curent_file)
            code_view.insert(file_content)
            self.sub_title = self.curent_file

    @on(ScreenResume)
    def on_resume(self) -> None:
        # Event handler called every time the screen is activated
        print("Editor screen resumed. Clearing code view")
        self.sub_title = "Select a file"
        self.query_one(DirectoryTree).focus()
        self.query_one(TextArea).clear()
        self.curent_file = ""

    def compose(self) -> ComposeResult:
        # Compose editor screen
        path = os.path.join(self.app.ROOT_PATH, 'configs')
        yield Header()
        with Container():
            yield DirectoryTree(path, id="tree-view")
            with VerticalScroll(id="code-view"):
                yield TextArea.code_editor("", id="code")
            with Horizontal(id="editor-buttons-container"):
                yield Button("Save", id="save-editor-button", classes="editor-button")
                yield Button("Cancel", id="cancel-editor-button", classes="editor-button")
        yield Footer()
