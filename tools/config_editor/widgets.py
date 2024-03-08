from textual.widget import Widget

from textual.widgets import Input, Label, Select

class LabelledInput(Widget):
    DEFAULT_CSS = """
    LabelledInput {
        width: 1fr;
        height: 4;
    }
    LabelledInput Label {
        padding-left: 1;
    }
    """

    def __init__(self,
                 label,
                 *,
                 placeholder="",
                 value="",
                 name=None,
                 id=None,
                 classes=None,
                 disabled=False):
        super().__init__(name=name, id=id, classes=classes, disabled=disabled)
        self.label = label
        self.placeholder = placeholder
        self.value = value

    def compose(self):
        yield Label(f"{self.label}:")
        yield Input(placeholder=self.placeholder, value=self.value)


class LabelledSelect(Widget):
    DEFAULT_CSS = """
    LabelledSelect {
        height: 4;
    }
    LabelledSelect Label {
        padding-left: 1;
    }
    """

    def __init__(self,
                 label,
                 options,
                 *,
                 prompt="Select",
                 allow_blank=True,
                 value=Select.BLANK,
                 name=None,
                 id=None,
                 classes=None,
                 disabled=False):
        super().__init__(name=name, id=id, classes=classes, disabled=disabled)
        self.label = label
        self.options = options
        self.value = value
        self.prompt = prompt
        self.allow_blank = allow_blank

    def compose(self):
        yield Label(f"{self.label}:")
        yield Select(options=self.options, value=self.value, prompt=self.prompt, allow_blank=self.allow_blank)
