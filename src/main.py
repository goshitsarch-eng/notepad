"""NotePad entry point.

Adds its own directory to ``sys.path`` so the module imports work both when the
app is run directly from a source checkout (``python3 src/main.py``) and when it
is installed by meson into ``pkgdatadir`` and launched via the generated wrapper.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from application import NotepadApplication  # noqa: E402


def main(version="dev"):
    app = NotepadApplication(version=version)
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
