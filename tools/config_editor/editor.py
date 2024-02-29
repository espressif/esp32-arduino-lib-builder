from textual.app import ComposeResult
from textual.containers import Container, VerticalScroll, Horizontal
from textual.screen import Screen
from textual.reactive import var
from textual.widgets import DirectoryTree, Footer, Header, TextArea, RichLog, Button

class EditorScreen(Screen):
    current_file = ""

    def compose(self) -> ComposeResult:
        """Compose our UI."""
        path = "./configs/"
        yield Header()
        with Container():
            yield DirectoryTree(path, id="tree-view")
            with VerticalScroll(id="code-view"):
                yield TextArea.code_editor("", id="code")
            with Horizontal(id="editor-buttons-container"):
                yield Button("Save", id="save-editor-button", classes="editor-button")
                yield Button("Cancel", id="cancel-editor-button", classes="editor-button")

    def on_mount(self) -> None:
        self.sub_title = "Select a file"
        self.query_one(DirectoryTree).focus()
        self.query_one(TextArea).clear()
        self.curent_file = ""

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Event handler called when a button is pressed."""
        code_view = self.query_one("#code", TextArea)
        if event.button.id == "save-editor-button" and self.curent_file != "":
            current_text = code_view.text
            try:
                file = open(self.curent_file, "w")
                file.write(current_text)
                file.close()
            except Exception:
                self.sub_title = "ERROR"
            else:
                self.sub_title = self.curent_file
                self.on_mount()
                self.dismiss()
        elif event.button.id == "cancel-editor-button":
            self.on_mount()
            self.dismiss()

    def on_directory_tree_file_selected(
        self, event: DirectoryTree.FileSelected
    ) -> None:
        """Called when the user click a file in the directory tree."""
        event.stop()
        code_view = self.query_one("#code", TextArea)
        code_view.clear()
        self.curent_file = str(event.path)
        try:
            file = open(self.curent_file, "r")
            file_content = file.read()
            file.close()
        except Exception:
            self.sub_title = "ERROR"
        else:
            code_view.insert(file_content)
            self.sub_title = self.curent_file

