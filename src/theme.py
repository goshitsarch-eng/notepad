"""Color scheme management, following the Kirigami color guidelines.

https://develop.kde.org/docs/getting-started/kirigami/style-colors/

The guidelines applied here:

- By default the app follows the system/platform color scheme instead of
  forcing one (``ColorScheme.SYSTEM``).
- Semantic palette roles (Window, Base, Text, Highlight, ...) are used
  everywhere; widgets never hardcode colors. This keeps contrast correct when
  the scheme switches between light and dark.
- The custom light and dark palettes are defined in this single module, in
  one place, so they can be reviewed for contrast together.
"""

from enum import Enum

from PySide6.QtCore import QSettings, Qt
from PySide6.QtGui import QColor, QGuiApplication, QPalette

_SETTINGS_ORG = "goshapps"
_SETTINGS_APP = "notepad"
_SCHEME_KEY = "color_scheme"


class ColorScheme(Enum):
    SYSTEM = "system"
    LIGHT = "light"
    DARK = "dark"


# Semantic colors for the light and dark schemes, modeled on the KDE Breeze
# light/dark color schemes. Every entry maps to a QPalette role; nothing in
# the widgets hardcodes a color value.
_LIGHT = {
    "window": "#eff0f1",
    "window_text": "#232629",
    "base": "#fcfcfc",
    "alternate_base": "#f5f6f7",
    "text": "#232629",
    "button": "#eff0f1",
    "button_text": "#232629",
    "highlight": "#3daee9",
    "highlighted_text": "#ffffff",
    "link": "#1d99f3",
    "tooltip_base": "#232629",
    "tooltip_text": "#fcfcfc",
}
_DARK = {
    "window": "#2a2e32",
    "window_text": "#fcfcfc",
    "base": "#1b1e20",
    "alternate_base": "#232629",
    "text": "#fcfcfc",
    "button": "#2a2e32",
    "button_text": "#fcfcfc",
    "highlight": "#3daee9",
    "highlighted_text": "#fcfcfc",
    "link": "#1d99f3",
    "tooltip_base": "#2a2e32",
    "tooltip_text": "#fcfcfc",
}


def _mix(a, b, t):
    """Mix ``a`` into ``b`` by the fraction ``t`` (0.0 -> a, 1.0 -> b)."""
    return QColor(
        round(a.red() + (b.red() - a.red()) * t),
        round(a.green() + (b.green() - a.green()) * t),
        round(a.blue() + (b.blue() - a.blue()) * t),
        round(a.alpha() + (b.alpha() - a.alpha()) * t),
    )


def _build(colors):
    palette = QPalette()
    window = QColor(colors["window"])
    text = QColor(colors["text"])
    disabled_text = _mix(text, window, 0.5)
    placeholder_text = _mix(text, window, 0.65)

    roles = {
        QPalette.ColorRole.Window: QColor(colors["window"]),
        QPalette.ColorRole.WindowText: QColor(colors["window_text"]),
        QPalette.ColorRole.Base: QColor(colors["base"]),
        QPalette.ColorRole.AlternateBase: QColor(colors["alternate_base"]),
        QPalette.ColorRole.Text: text,
        QPalette.ColorRole.Button: QColor(colors["button"]),
        QPalette.ColorRole.ButtonText: QColor(colors["button_text"]),
        QPalette.ColorRole.Highlight: QColor(colors["highlight"]),
        QPalette.ColorRole.HighlightedText: QColor(colors["highlighted_text"]),
        QPalette.ColorRole.Link: QColor(colors["link"]),
        QPalette.ColorRole.LinkVisited: QColor(colors["link"]),
        QPalette.ColorRole.ToolTipBase: QColor(colors["tooltip_base"]),
        QPalette.ColorRole.ToolTipText: QColor(colors["tooltip_text"]),
        QPalette.ColorRole.PlaceholderText: placeholder_text,
    }
    for group in (
        QPalette.ColorGroup.Active,
        QPalette.ColorGroup.Inactive,
        QPalette.ColorGroup.Disabled,
    ):
        for role, color in roles.items():
            palette.setColor(group, role, color)
        palette.setColor(group, QPalette.ColorRole.Text, disabled_text if group == QPalette.ColorGroup.Disabled else text)
        palette.setColor(group, QPalette.ColorRole.WindowText, disabled_text if group == QPalette.ColorGroup.Disabled else QColor(colors["window_text"]))
        palette.setColor(group, QPalette.ColorRole.ButtonText, disabled_text if group == QPalette.ColorGroup.Disabled else QColor(colors["button_text"]))
    return palette


_LIGHT_PALETTE = _build(_LIGHT)
_DARK_PALETTE = _build(_DARK)


def palette_for(scheme):
    """Return the palette for LIGHT or DARK, or None for SYSTEM."""
    if scheme is ColorScheme.DARK:
        return QPalette(_DARK_PALETTE)
    if scheme is ColorScheme.LIGHT:
        return QPalette(_LIGHT_PALETTE)
    return None


def apply(app, scheme):
    """Apply ``scheme`` to the application.

    SYSTEM restores the style's standard palette, which follows the platform
    color scheme (e.g. Plasma light/dark preferences).
    """
    palette = palette_for(scheme)
    if palette is None:
        app.setPalette(app.style().standardPalette())
    else:
        app.setPalette(palette)


def system_is_dark():
    """Whether the platform reports a dark color scheme (Qt >= 6.5)."""
    hints = QGuiApplication.styleHints()
    if hints is None:
        return False
    color_scheme = getattr(hints, "colorScheme", None)
    if color_scheme is None:
        return False
    return color_scheme() == Qt.ColorScheme.Dark


def effective_is_dark(scheme):
    if scheme is ColorScheme.DARK:
        return True
    if scheme is ColorScheme.LIGHT:
        return False
    return system_is_dark()


def load_scheme(settings=None):
    settings = settings or QSettings(_SETTINGS_ORG, _SETTINGS_APP)
    raw = settings.value(_SCHEME_KEY, ColorScheme.SYSTEM.value)
    try:
        return ColorScheme(raw)
    except ValueError:
        return ColorScheme.SYSTEM


def save_scheme(scheme, settings=None):
    settings = settings or QSettings(_SETTINGS_ORG, _SETTINGS_APP)
    settings.setValue(_SCHEME_KEY, scheme.value)
