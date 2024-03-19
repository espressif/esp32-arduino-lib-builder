from textual.widget import Widget

from textual.widgets import Input, Label, Select

class LabelledInput(Widget):
    DEFAULT_CSS = """
    LabelledInput {
        height: 4;
        margin-bottom: 1;
    }
    LabelledInput Label {
        padding-left: 1;
    }
    """

    label_widget: Label
    input_widget: Input

    def set_input_value(self, value):
        self.input_widget.value = value

    def get_input_value(self):
        return self.input_widget.value

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
        self.__label = label
        self.__placeholder = placeholder
        self.__init_value = value

    def compose(self):
        self.label_widget = Label(f"{self.__label}:")
        self.input_widget = Input(placeholder=self.__placeholder, value=self.__init_value)
        yield self.label_widget
        yield self.input_widget


class LabelledSelect(Widget):
    DEFAULT_CSS = """
    LabelledSelect {
        height: 4;
        margin-bottom: 1;
    }
    LabelledSelect Label {
        padding-left: 1;
    }
    """

    label_widget: Label
    select_widget: Select

    def set_select_options(self, options):
        self.__options = options
        self.select_widget.options = options

    def get_select_options(self):
        return self.__options

    def set_select_value(self, value):
        self.select_widget.value = value

    def get_select_value(self):
        return self.select_widget.value

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
        self.__label = label
        self.__options = options
        self.__init_value = value
        self.__prompt = prompt
        self.__allow_blank = allow_blank

    def compose(self):
        self.label_widget = Label(f"{self.__label}:")
        self.select_widget = Select(options=self.__options, value=self.__init_value, prompt=self.__prompt, allow_blank=self.__allow_blank)
        yield self.label_widget
        yield self.select_widget
