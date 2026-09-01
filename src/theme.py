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
from PySide6.QtWidgets import QStyleFactory

_SETTINGS_ORG = "goshapps"
_SETTINGS_APP = "notepad"
_SCHEME_KEY = "color_scheme"
_EXPLICIT_STYLE = "Fusion"
_SYSTEM_STYLE_ATTRIBUTE = "_notepad_system_style"


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
    "light": "#ffffff",
    "midlight": "#f7f8f8",
    "dark": "#8b9297",
    "mid": "#b7bcc0",
    "shadow": "#474b4f",
    "bright_text": "#ffffff",
    "highlight": "#3daee9",
    "highlighted_text": "#17242b",
    "link": "#006eaa",
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
    "light": "#555c63",
    "midlight": "#3c4248",
    "dark": "#121416",
    "mid": "#202428",
    "shadow": "#000000",
    "bright_text": "#ffffff",
    "highlight": "#1676a3",
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
    base = QColor(colors["base"])
    button = QColor(colors["button"])
    text = QColor(colors["text"])
    window_text = QColor(colors["window_text"])
    button_text = QColor(colors["button_text"])
    highlight = QColor(colors["highlight"])
    highlighted_text = QColor(colors["highlighted_text"])
    placeholder_text = _mix(text, base, 0.65)

    roles = {
        QPalette.ColorRole.Window: window,
        QPalette.ColorRole.WindowText: window_text,
        QPalette.ColorRole.Base: base,
        QPalette.ColorRole.AlternateBase: QColor(colors["alternate_base"]),
        QPalette.ColorRole.Text: text,
        QPalette.ColorRole.Button: button,
        QPalette.ColorRole.ButtonText: button_text,
        QPalette.ColorRole.Light: QColor(colors["light"]),
        QPalette.ColorRole.Midlight: QColor(colors["midlight"]),
        QPalette.ColorRole.Dark: QColor(colors["dark"]),
        QPalette.ColorRole.Mid: QColor(colors["mid"]),
        QPalette.ColorRole.Shadow: QColor(colors["shadow"]),
        QPalette.ColorRole.BrightText: QColor(colors["bright_text"]),
        QPalette.ColorRole.Highlight: highlight,
        QPalette.ColorRole.HighlightedText: highlighted_text,
        QPalette.ColorRole.Link: QColor(colors["link"]),
        QPalette.ColorRole.LinkVisited: QColor(colors["link"]),
        QPalette.ColorRole.ToolTipBase: QColor(colors["tooltip_base"]),
        QPalette.ColorRole.ToolTipText: QColor(colors["tooltip_text"]),
        QPalette.ColorRole.PlaceholderText: placeholder_text,
    }
    accent_role = getattr(QPalette.ColorRole, "Accent", None)
    if accent_role is not None:
        roles[accent_role] = highlight

    for group in (
        QPalette.ColorGroup.Active,
        QPalette.ColorGroup.Inactive,
        QPalette.ColorGroup.Disabled,
    ):
        for role, color in roles.items():
            palette.setColor(group, role, color)
        if group == QPalette.ColorGroup.Disabled:
            disabled_highlight = _mix(highlight, window, 0.5)
            palette.setColor(group, QPalette.ColorRole.Text, _mix(text, base, 0.5))
            palette.setColor(
                group,
                QPalette.ColorRole.WindowText,
                _mix(window_text, window, 0.5),
            )
            palette.setColor(
                group,
                QPalette.ColorRole.ButtonText,
                _mix(button_text, button, 0.5),
            )
            palette.setColor(group, QPalette.ColorRole.Highlight, disabled_highlight)
            palette.setColor(
                group,
                QPalette.ColorRole.HighlightedText,
                _mix(highlighted_text, disabled_highlight, 0.25),
            )
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


def _remember_system_style(app):
    style_name = getattr(app, _SYSTEM_STYLE_ATTRIBUTE, None)
    if style_name is not None:
        return style_name

    object_name = app.style().objectName()
    style_name = next(
        (
            key
            for key in QStyleFactory.keys()
            if key.casefold() == object_name.casefold()
        ),
        object_name,
    )
    setattr(app, _SYSTEM_STYLE_ATTRIBUTE, style_name)
    return style_name


def _set_style(app, style_name):
    if app.style().objectName().casefold() == style_name.casefold():
        return
    style = QStyleFactory.create(style_name)
    if style is None:
        raise RuntimeError(f'Qt style "{style_name}" is unavailable')
    app.setStyle(style)


def apply(app, scheme):
    """Apply ``scheme`` to the application.

    KDE platform styles can polish individual widgets with class- or
    widget-specific palettes. Those local brushes outrank an application
    palette and can leave dark host foregrounds on explicit light backgrounds.
    Explicit modes therefore use Qt's palette-driven Fusion style and apply one
    complete semantic palette after the style switch. SYSTEM restores the
    original platform style and an unresolved palette, allowing Qt to resolve
    the live platform theme again.
    """
    system_style = _remember_system_style(app)
    palette = palette_for(scheme)
    if palette is None:
        _set_style(app, system_style)
        app.setPalette(QPalette())
    else:
        _set_style(app, _EXPLICIT_STYLE)
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
