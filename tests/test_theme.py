#!/usr/bin/env python3
"""Unit tests for the Kirigami-style light/dark color scheme module."""

import os
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from PySide6.QtCore import QSettings  # noqa: E402
from PySide6.QtGui import QPalette  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

import theme  # noqa: E402
from theme import ColorScheme  # noqa: E402

_app = QApplication.instance() or QApplication([])

_BASE = QPalette.ColorRole.Base
_WINDOW = QPalette.ColorRole.Window
_TEXT = QPalette.ColorRole.Text


class PaletteTests(unittest.TestCase):
    def test_light_base_is_light_and_dark_base_is_dark(self):
        light = theme.palette_for(ColorScheme.LIGHT)
        dark = theme.palette_for(ColorScheme.DARK)
        self.assertGreater(light.color(_BASE).lightness(), 200)
        self.assertLess(dark.color(_BASE).lightness(), 60)

    def test_light_and_dark_palettes_differ(self):
        light = theme.palette_for(ColorScheme.LIGHT)
        dark = theme.palette_for(ColorScheme.DARK)
        self.assertNotEqual(light.color(_WINDOW), dark.color(_WINDOW))
        self.assertNotEqual(light.color(_BASE), dark.color(_BASE))

    def test_text_contrasts_the_base_in_both_schemes(self):
        # WCAG-style sanity check: text and editor background lightness must
        # be far enough apart to stay readable in both schemes.
        for scheme in (ColorScheme.LIGHT, ColorScheme.DARK):
            palette = theme.palette_for(scheme)
            delta = abs(
                palette.color(_TEXT).lightness() - palette.color(_BASE).lightness()
            )
            self.assertGreater(delta, 150, scheme)

    def test_palette_for_system_returns_none(self):
        self.assertIsNone(theme.palette_for(ColorScheme.SYSTEM))

    def test_disabled_text_is_dimmed(self):
        dark = theme.palette_for(ColorScheme.DARK)
        active = dark.color(QPalette.ColorGroup.Active, _TEXT)
        disabled = dark.color(QPalette.ColorGroup.Disabled, _TEXT)
        self.assertNotEqual(active, disabled)

    def test_apply_switches_the_application_palette(self):
        theme.apply(_app, ColorScheme.DARK)
        self.assertLess(_app.palette().color(_BASE).lightness(), 60)
        theme.apply(_app, ColorScheme.LIGHT)
        self.assertGreater(_app.palette().color(_BASE).lightness(), 200)
        theme.apply(_app, ColorScheme.SYSTEM)  # must restore without error

    def test_effective_is_dark_for_explicit_schemes(self):
        self.assertTrue(theme.effective_is_dark(ColorScheme.DARK))
        self.assertFalse(theme.effective_is_dark(ColorScheme.LIGHT))


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        path = os.path.join(self._tmp.name, "notepad.ini")
        self.settings = QSettings(path, QSettings.Format.IniFormat)

    def tearDown(self):
        self.settings = None
        self._tmp.cleanup()

    def test_load_defaults_to_system(self):
        self.assertIs(theme.load_scheme(self.settings), ColorScheme.SYSTEM)

    def test_roundtrip(self):
        theme.save_scheme(ColorScheme.DARK, self.settings)
        self.assertIs(theme.load_scheme(self.settings), ColorScheme.DARK)
        theme.save_scheme(ColorScheme.LIGHT, self.settings)
        self.assertIs(theme.load_scheme(self.settings), ColorScheme.LIGHT)

    def test_invalid_value_falls_back_to_system(self):
        self.settings.setValue("color_scheme", "bogus")
        self.assertIs(theme.load_scheme(self.settings), ColorScheme.SYSTEM)


if __name__ == "__main__":
    unittest.main()
