#!/usr/bin/env python3
"""Unit tests for NotePad Find / Replace / Go To helpers (Qt 6)."""

import os
import sys
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from PySide6.QtGui import QTextCursor  # noqa: E402
from PySide6.QtWidgets import QApplication, QPlainTextEdit  # noqa: E402

from commands import (  # noqa: E402
    find_next,
    goto_line,
    replace_all,
    replace_and_find_next,
    selected_text,
    selection_matches,
)

_app = QApplication.instance() or QApplication([])


def _edit(text):
    edit = QPlainTextEdit()
    edit.setPlainText(text)
    cursor = edit.textCursor()
    cursor.movePosition(QTextCursor.MoveOperation.Start)
    edit.setTextCursor(cursor)
    return edit


def _document_text(edit):
    return edit.toPlainText()


class FindNextTests(unittest.TestCase):
    def test_finds_first_match_from_start(self):
        edit = _edit("one two one")
        self.assertTrue(find_next(edit, "one"))
        self.assertEqual(selected_text(edit), "one")
        self.assertEqual(edit.textCursor().selectionStart(), 0)

    def test_skips_current_selection_to_next_match(self):
        edit = _edit("one two one")
        self.assertTrue(find_next(edit, "one"))
        self.assertTrue(find_next(edit, "one"))
        cursor = edit.textCursor()
        self.assertEqual(cursor.selectionStart(), 8)
        self.assertEqual(cursor.selectionEnd(), 11)

    def test_wraps_around_to_first_match(self):
        edit = _edit("one two one")
        find_next(edit, "one")
        find_next(edit, "one")
        self.assertTrue(find_next(edit, "one"))
        self.assertEqual(edit.textCursor().selectionStart(), 0)

    def test_case_insensitive_by_default(self):
        edit = _edit("Hello HELLO")
        self.assertTrue(find_next(edit, "hello"))
        self.assertEqual(selected_text(edit), "Hello")

    def test_match_case(self):
        edit = _edit("Hello hello")
        self.assertTrue(find_next(edit, "hello", match_case=True))
        self.assertEqual(selected_text(edit), "hello")

    def test_missing_text_returns_false(self):
        edit = _edit("hello")
        self.assertFalse(find_next(edit, "xyz"))
        self.assertFalse(find_next(edit, ""))


class ReplaceTests(unittest.TestCase):
    def test_replace_current_then_find_next(self):
        edit = _edit("one two one")
        self.assertTrue(find_next(edit, "one"))
        result = replace_and_find_next(edit, "one", "ONE")
        self.assertEqual(result, "replaced")
        self.assertEqual(_document_text(edit), "ONE two one")
        self.assertEqual(selected_text(edit), "one")

    def test_replace_finds_first_if_nothing_selected(self):
        edit = _edit("one two one")
        result = replace_and_find_next(edit, "one", "ONE")
        self.assertEqual(result, "found")
        self.assertEqual(selected_text(edit), "one")

    def test_replace_all(self):
        edit = _edit("one two one two one")
        count = replace_all(edit, "one", "ONE")
        self.assertEqual(count, 3)
        self.assertEqual(_document_text(edit), "ONE two ONE two ONE")

    def test_replace_all_is_case_sensitive_when_asked(self):
        edit = _edit("One one ONE")
        count = replace_all(edit, "one", "x", match_case=True)
        self.assertEqual(count, 1)
        self.assertEqual(_document_text(edit), "One x ONE")

    def test_replace_all_empty_needle_is_noop(self):
        edit = _edit("abc")
        self.assertEqual(replace_all(edit, "", "x"), 0)

    def test_replace_all_is_a_single_undo_step(self):
        edit = _edit("one two one")
        replace_all(edit, "one", "ONE")
        edit.undo()
        self.assertEqual(_document_text(edit), "one two one")

    def test_selection_matches_ignores_case_by_default(self):
        edit = _edit("Hello")
        cursor = edit.textCursor()
        cursor.select(QTextCursor.SelectionType.Document)
        edit.setTextCursor(cursor)
        self.assertTrue(selection_matches(edit, "hello"))
        self.assertFalse(selection_matches(edit, "hello", match_case=True))

    def test_selected_text_normalizes_paragraph_separators(self):
        edit = _edit("a\nb")
        cursor = edit.textCursor()
        cursor.select(QTextCursor.SelectionType.Document)
        edit.setTextCursor(cursor)
        self.assertEqual(selected_text(edit), "a\nb")


class GoToLineTests(unittest.TestCase):
    def test_goes_to_requested_line(self):
        edit = _edit("a\nb\nc")
        self.assertTrue(goto_line(edit, 2))
        cursor = edit.textCursor()
        self.assertEqual(cursor.blockNumber(), 1)
        self.assertEqual(cursor.columnNumber(), 0)

    def test_rejects_out_of_range(self):
        edit = _edit("a\nb")
        self.assertFalse(goto_line(edit, 0))
        self.assertFalse(goto_line(edit, 3))
        self.assertTrue(goto_line(edit, 2))

    def test_rejects_far_out_of_range(self):
        edit = _edit("a\nb")
        self.assertFalse(goto_line(edit, 100))


if __name__ == "__main__":
    unittest.main()
