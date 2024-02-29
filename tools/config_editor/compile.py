from textual.app import ComposeResult
from textual.containers import Container
from textual.screen import Screen
from textual.widgets import Footer, Header, Static, RichLog

class CompileScreen(Screen):

    def compose(self) -> ComposeResult:
        """Compose our UI."""
        yield Header()
        with Container():
            yield Static("Compile", id="compile-title")

    def on_mount(self) -> None:
        pass


