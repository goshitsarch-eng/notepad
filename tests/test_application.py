"""Regression tests for external and secondary-instance file opens."""

import os
import sys
import tempfile
import unittest
from types import SimpleNamespace

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from PySide6.QtWidgets import QApplication

from application import NotepadApplication
from window import NotepadWindow

_app = QApplication.instance() or QApplication([])


class ExternalOpenTests(unittest.TestCase):
    def setUp(self):
        self.window = NotepadWindow(version="test")
        self.tempdir = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.tempdir.name, "incoming.txt")
        with open(self.path, "w", encoding="utf-8") as handle:
            handle.write("SECOND INSTANCE FILE")

    def tearDown(self):
        self.window.edit.document().setModified(False)
        self.window.close()
        self.tempdir.cleanup()

    def test_cancelled_external_open_preserves_unsaved_text(self):
        self.window.edit.setPlainText("UNSAVED USER DATA")
        self.window.edit.document().setModified(True)
        self.window._guard_unsaved = lambda proceed: None

        self.window.open_path(self.path)

        self.assertEqual(self.window.edit.toPlainText(), "UNSAVED USER DATA")
        self.assertTrue(self.window.edit.document().isModified())
        self.assertIsNone(self.window.file_path)

    def test_application_routes_external_paths_through_guarded_open(self):
        calls = []
        fake_window = SimpleNamespace(
            open_path=calls.append,
            show=lambda: None,
            raise_=lambda: None,
            activateWindow=lambda: None,
        )
        fake_application = SimpleNamespace(ensure_window=lambda: fake_window)

        NotepadApplication.open_paths(fake_application, [self.path], present=False)

        self.assertEqual(calls, [self.path])


if __name__ == "__main__":
    unittest.main()
