"""NotePad entry point.

Adds its own directory to ``sys.path`` so the module imports work both when the
app is run directly from a source checkout (``python3 src/main.py``) and when it
is installed by meson into ``pkgdatadir`` and launched via the generated wrapper.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import theme  # noqa: E402
from application import NotepadApplication  # noqa: E402


def main(version="dev"):
    files = [
        os.path.abspath(arg)
        for arg in sys.argv[1:]
        if arg and not arg.startswith("-")
    ]
    app = NotepadApplication(sys.argv, version=version)
    if app.forward_to_running_instance(files):
        return 0
    app.listen_for_instances()
    theme.apply(app, theme.load_scheme())
    app.open_paths(files, present=True)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
