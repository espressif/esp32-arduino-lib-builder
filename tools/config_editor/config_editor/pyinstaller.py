import PyInstaller.__main__
from pathlib import Path

main_folder = Path(__file__).parent.absolute()
path_to_main = str(main_folder / "main.py")

def install():
    PyInstaller.__main__.run([
        path_to_main,
        '--onefile',
        '--windowed',
        # other pyinstaller options...
    ])
