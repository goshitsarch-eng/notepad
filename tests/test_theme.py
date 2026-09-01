#!/usr/bin/env python3
"""Unit tests for the Kirigami-style light/dark color scheme module."""

import os
import sys
import tempfile
import unittest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from PySide6.QtCore import QSettings, Qt  # noqa: E402
from PySide6.QtGui import QPalette  # noqa: E402
from PySide6.QtWidgets import (  # noqa: E402
    QApplication,
    QDialog,
    QLabel,
    QLineEdit,
    QMenu,
    QMenuBar,
    QProxyStyle,
    QPushButton,
    QStyleOptionMenuItem,
)

import theme  # noqa: E402
from theme import ColorScheme  # noqa: E402
from window import NotepadWindow  # noqa: E402

_app = QApplication.instance() or QApplication([])

_BASE = QPalette.ColorRole.Base
_WINDOW = QPalette.ColorRole.Window
_TEXT = QPalette.ColorRole.Text
_GROUPS = (
    QPalette.ColorGroup.Active,
    QPalette.ColorGroup.Inactive,
    QPalette.ColorGroup.Disabled,
)
_INITIAL_STYLE = _app.style().objectName()


def contrast_ratio(first, second):
    def relative_luminance(color):
        channels = []
        for channel in (color.redF(), color.greenF(), color.blueF()):
            channels.append(
                channel / 12.92
                if channel <= 0.04045
                else ((channel + 0.055) / 1.055) ** 2.4
            )
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

    light, dark = sorted(
        (relative_luminance(first), relative_luminance(second)), reverse=True
    )
    return (light + 0.05) / (dark + 0.05)


class HostDarkMenuStyle(QProxyStyle):
    """Model a KDE style that gives polished menu bars a local dark palette."""

    def __init__(self):
        super().__init__("Fusion")
        self.setObjectName("host-dark-menu-style")

    def polish(self, target):
        result = super().polish(target)
        if isinstance(target, QMenuBar):
            light = theme.palette_for(ColorScheme.LIGHT)
            dark = theme.palette_for(ColorScheme.DARK)
            palette = QPalette(target.palette())
            for group in _GROUPS:
                palette.setColor(group, _WINDOW, light.color(group, _WINDOW))
                palette.setColor(
                    group,
                    QPalette.ColorRole.WindowText,
                    dark.color(group, QPalette.ColorRole.WindowText),
                )
                palette.setColor(group, _TEXT, dark.color(group, _TEXT))
            target.setPalette(palette)
        return result

    def unpolish(self, target):
        if isinstance(target, QMenuBar):
            target.setPalette(QPalette())
        return super().unpolish(target)


class PaletteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Let theme.py remember the real platform style before a regression
        # test installs the deliberately hostile style above.
        theme.apply(_app, ColorScheme.SYSTEM)

    def tearDown(self):
        _app.setStyle(_INITIAL_STYLE)
        _app.setPalette(QPalette())

    def test_explicit_light_replaces_host_style_palette_on_existing_menu_bar(self):
        theme.apply(_app, ColorScheme.DARK)
        _app.setStyle(HostDarkMenuStyle())
        window = NotepadWindow(version="test")
        window.show()
        _app.processEvents()

        menu_bar = window.menuBar()
        light = theme.palette_for(ColorScheme.LIGHT)
        self.assertTrue(menu_bar.testAttribute(Qt.WidgetAttribute.WA_SetPalette))
        self.assertEqual(
            menu_bar.palette().color(QPalette.ColorRole.WindowText),
            theme.palette_for(ColorScheme.DARK).color(QPalette.ColorRole.WindowText),
        )

        theme.apply(_app, ColorScheme.LIGHT)
        _app.processEvents()

        self.assertEqual(_app.style().objectName().casefold(), "fusion")
        self.assertFalse(menu_bar.testAttribute(Qt.WidgetAttribute.WA_SetPalette))
        for group in _GROUPS:
            for role in (
                QPalette.ColorRole.Window,
                QPalette.ColorRole.WindowText,
                QPalette.ColorRole.Text,
                QPalette.ColorRole.Highlight,
                QPalette.ColorRole.HighlightedText,
            ):
                self.assertEqual(
                    menu_bar.palette().color(group, role),
                    light.color(group, role),
                    (group, role),
                )
        window.close()

    def test_light_palette_reaches_menu_popup_dialog_editor_and_find_widgets(self):
        theme.apply(_app, ColorScheme.LIGHT)
        window = NotepadWindow(version="test")
        popup = QMenu("Popup", window)
        popup.addAction("Enabled")
        disabled_action = popup.addAction("Disabled")
        disabled_action.setEnabled(False)
        dialog = QDialog(window)
        dialog_label = QLabel("Dialog text", dialog)
        dialog_entry = QLineEdit(dialog)
        dialog_button = QPushButton("Dialog button", dialog)

        expected = theme.palette_for(ColorScheme.LIGHT)
        popup.ensurePolished()
        popup_option = QStyleOptionMenuItem()
        popup_option.initFrom(popup)
        self.assertEqual(
            popup_option.palette.color(QPalette.ColorRole.WindowText),
            expected.color(QPalette.ColorRole.WindowText),
        )
        self.assertEqual(
            popup_option.palette.color(QPalette.ColorRole.Text),
            expected.color(QPalette.ColorRole.Text),
        )

        surfaces = (
            (window.menuBar(), QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
            (popup, QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
            (dialog, QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
            (dialog_label, QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
            (window.edit, QPalette.ColorRole.Base, QPalette.ColorRole.Text),
            (window.find_bar, QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
            (window.find_bar.entry, QPalette.ColorRole.Base, QPalette.ColorRole.Text),
            (dialog_entry, QPalette.ColorRole.Base, QPalette.ColorRole.Text),
            (window.find_bar.next_btn, QPalette.ColorRole.Button, QPalette.ColorRole.ButtonText),
            (window.find_bar.close_btn, QPalette.ColorRole.Button, QPalette.ColorRole.ButtonText),
            (dialog_button, QPalette.ColorRole.Button, QPalette.ColorRole.ButtonText),
            (window.pos_label, QPalette.ColorRole.Window, QPalette.ColorRole.WindowText),
        )
        for widget, background_role, foreground_role in surfaces:
            for group in _GROUPS:
                palette = widget.palette()
                self.assertEqual(
                    palette.color(group, background_role),
                    expected.color(group, background_role),
                    (type(widget).__name__, group, background_role),
                )
                self.assertEqual(
                    palette.color(group, foreground_role),
                    expected.color(group, foreground_role),
                    (type(widget).__name__, group, foreground_role),
                )
                self.assertEqual(
                    palette.color(group, QPalette.ColorRole.Highlight),
                    expected.color(group, QPalette.ColorRole.Highlight),
                    (type(widget).__name__, group, "selection background"),
                )
                self.assertEqual(
                    palette.color(group, QPalette.ColorRole.HighlightedText),
                    expected.color(group, QPalette.ColorRole.HighlightedText),
                    (type(widget).__name__, group, "selection text"),
                )

        self.assertLess(expected.color(QPalette.ColorRole.WindowText).lightness(), 80)
        self.assertLess(expected.color(QPalette.ColorRole.Text).lightness(), 80)
        self.assertLess(expected.color(QPalette.ColorRole.ButtonText).lightness(), 80)
        self.assertLess(expected.color(QPalette.ColorRole.HighlightedText).lightness(), 80)

        dialog.close()
        popup.close()
        window.close()

    def test_system_restores_platform_style_and_palette_after_explicit_mode(self):
        theme.apply(_app, ColorScheme.SYSTEM)
        system_style = _app.style().objectName()
        system_palette = QPalette(_app.palette())

        theme.apply(_app, ColorScheme.DARK)
        self.assertEqual(_app.style().objectName().casefold(), "fusion")
        theme.apply(_app, ColorScheme.SYSTEM)

        self.assertEqual(_app.style().objectName(), system_style)
        self.assertEqual(_app.palette(), system_palette)

    def test_theme_button_has_visible_text_without_theme_icons(self):
        window = NotepadWindow(version="test")
        self.assertIn(window.theme_button.text(), {"Light", "Dark"})
        self.assertEqual(window.theme_button.accessibleName(), "Color scheme")
        window.close()

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

    def test_foreground_contrast_covers_active_disabled_and_selected_states(self):
        role_pairs = (
            (QPalette.ColorRole.WindowText, QPalette.ColorRole.Window),
            (QPalette.ColorRole.Text, QPalette.ColorRole.Base),
            (QPalette.ColorRole.ButtonText, QPalette.ColorRole.Button),
            (QPalette.ColorRole.HighlightedText, QPalette.ColorRole.Highlight),
            (QPalette.ColorRole.ToolTipText, QPalette.ColorRole.ToolTipBase),
        )
        for scheme in (ColorScheme.LIGHT, ColorScheme.DARK):
            palette = theme.palette_for(scheme)
            for group in _GROUPS:
                minimum = 2.9 if group == QPalette.ColorGroup.Disabled else 4.5
                for foreground_role, background_role in role_pairs:
                    ratio = contrast_ratio(
                        palette.color(group, foreground_role),
                        palette.color(group, background_role),
                    )
                    self.assertGreaterEqual(
                        ratio,
                        minimum,
                        (scheme, group, foreground_role, background_role, ratio),
                    )

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
