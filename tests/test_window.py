#!/usr/bin/env python3
"""UI regression tests for the NotePad main window."""

import os
import sys
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from window import NotepadWindow  # noqa: E402

_app = QApplication.instance() or QApplication([])


class FindBarTests(unittest.TestCase):
    def setUp(self):
        self.window = NotepadWindow(version="test")
        self.window.show()
        _app.processEvents()

    def tearDown(self):
        self.window.edit.document().setModified(False)
        self.window.close()
        _app.processEvents()

    def _open_find_bar(self):
        self.window.on_find()
        _app.processEvents()
        self.assertTrue(self.window.find_bar.isVisible())
        self.assertTrue(self.window.find_bar.entry.hasFocus())

    def test_find_bar_has_visible_accessible_close_button(self):
        self._open_find_bar()

        close_btn = self.window.find_bar.close_btn
        self.assertTrue(close_btn.isVisible())
        self.assertFalse(close_btn.icon().isNull())
        self.assertEqual(close_btn.accessibleName(), "Close Find")
        self.assertIn("Esc", close_btn.toolTip())

    def test_close_button_hides_find_bar_and_returns_focus_to_editor(self):
        self._open_find_bar()

        QTest.mouseClick(self.window.find_bar.close_btn, Qt.MouseButton.LeftButton)
        _app.processEvents()

        self.assertFalse(self.window.find_bar.isVisible())
        self.assertTrue(self.window.edit.hasFocus())

    def test_escape_hides_find_bar_and_returns_focus_to_editor(self):
        self._open_find_bar()

        QTest.keyClick(self.window.find_bar.entry, Qt.Key.Key_Escape)
        _app.processEvents()

        self.assertFalse(self.window.find_bar.isVisible())
        self.assertTrue(self.window.edit.hasFocus())


if __name__ == "__main__":
    unittest.main()
