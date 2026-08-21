#!/usr/bin/env python3
"""Unit tests for NotePad Find / Replace / Go To helpers."""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Pango", "1.0")

from gi.repository import Gtk, Pango  # noqa: E402

from commands import (  # noqa: E402
    find_next,
    font_css,
    goto_line,
    replace_all,
    replace_and_find_next,
    selected_text,
    selection_matches,
)


def _buffer(text):
    buf = Gtk.TextBuffer()
    buf.set_text(text)
    buf.place_cursor(buf.get_start_iter())
    return buf


class FindNextTests(unittest.TestCase):
    def test_finds_first_match_from_start(self):
        buf = _buffer("one two one")
        self.assertTrue(find_next(buf, "one"))
        self.assertEqual(selected_text(buf), "one")
        self.assertEqual(buf.get_iter_at_mark(buf.get_insert()).get_offset(), 0)

    def test_skips_current_selection_to_next_match(self):
        buf = _buffer("one two one")
        self.assertTrue(find_next(buf, "one"))
        self.assertTrue(find_next(buf, "one"))
        start, end = buf.get_selection_bounds()
        self.assertEqual(start.get_offset(), 8)
        self.assertEqual(end.get_offset(), 11)

    def test_wraps_around_to_first_match(self):
        buf = _buffer("one two one")
        find_next(buf, "one")
        find_next(buf, "one")
        self.assertTrue(find_next(buf, "one"))
        self.assertEqual(buf.get_iter_at_mark(buf.get_insert()).get_offset(), 0)

    def test_case_insensitive_by_default(self):
        buf = _buffer("Hello HELLO")
        self.assertTrue(find_next(buf, "hello"))
        self.assertEqual(selected_text(buf), "Hello")

    def test_match_case(self):
        buf = _buffer("Hello hello")
        self.assertTrue(find_next(buf, "hello", match_case=True))
        self.assertEqual(selected_text(buf), "hello")

    def test_missing_text_returns_false(self):
        buf = _buffer("hello")
        self.assertFalse(find_next(buf, "xyz"))
        self.assertFalse(find_next(buf, ""))


class ReplaceTests(unittest.TestCase):
    def test_replace_current_then_find_next(self):
        buf = _buffer("one two one")
        self.assertTrue(find_next(buf, "one"))
        result = replace_and_find_next(buf, "one", "ONE")
        self.assertEqual(result, "replaced")
        start, end = buf.get_bounds()
        self.assertEqual(buf.get_text(start, end, True), "ONE two one")
        self.assertEqual(selected_text(buf), "one")

    def test_replace_finds_first_if_nothing_selected(self):
        buf = _buffer("one two one")
        result = replace_and_find_next(buf, "one", "ONE")
        self.assertEqual(result, "found")
        self.assertEqual(selected_text(buf), "one")

    def test_replace_all(self):
        buf = _buffer("one two one two one")
        count = replace_all(buf, "one", "ONE")
        self.assertEqual(count, 3)
        start, end = buf.get_bounds()
        self.assertEqual(buf.get_text(start, end, True), "ONE two ONE two ONE")

    def test_replace_all_is_case_sensitive_when_asked(self):
        buf = _buffer("One one ONE")
        count = replace_all(buf, "one", "x", match_case=True)
        self.assertEqual(count, 1)
        start, end = buf.get_bounds()
        self.assertEqual(buf.get_text(start, end, True), "One x ONE")

    def test_replace_all_empty_needle_is_noop(self):
        buf = _buffer("abc")
        self.assertEqual(replace_all(buf, "", "x"), 0)

    def test_selection_matches_ignores_case_by_default(self):
        buf = _buffer("Hello")
        buf.select_range(buf.get_start_iter(), buf.get_end_iter())
        self.assertTrue(selection_matches(buf, "hello"))
        self.assertFalse(selection_matches(buf, "hello", match_case=True))


class GoToLineTests(unittest.TestCase):
    def test_goes_to_requested_line(self):
        buf = _buffer("a\nb\nc")
        self.assertTrue(goto_line(buf, 2))
        insert = buf.get_iter_at_mark(buf.get_insert())
        self.assertEqual(insert.get_line(), 1)
        self.assertEqual(insert.get_line_offset(), 0)

    def test_rejects_out_of_range(self):
        buf = _buffer("a\nb")
        self.assertFalse(goto_line(buf, 0))
        self.assertFalse(goto_line(buf, 3))
        self.assertTrue(goto_line(buf, 2))


class FontCssTests(unittest.TestCase):
    def test_emits_family_size_weight_and_style(self):
        desc = Pango.FontDescription.from_string("Serif Italic 14")
        css = font_css(desc)
        self.assertIn('font-family: "Serif"', css)
        self.assertIn("font-size: 14pt", css)
        self.assertIn("font-style: italic", css)
        self.assertIn("notepad-text", css)


if __name__ == "__main__":
    unittest.main()
