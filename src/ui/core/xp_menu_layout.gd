class_name XpMenuLayout
extends RefCounted
## Widths that Luna menus reserve, measured from the Luna menu metrics.

const _LABEL_PADDING := 11.0
const _ROW_LEFT_INSET := 22.0
const _ROW_RIGHT_INSET := 20.0
const _SHORTCUT_GAP := 24.0
const _MIN_WIDTH := 168.0
const SEPARATOR_HEIGHT := 6.0
## The popup's border, one pixel on each side, and two pixels of padding above and below.
const _FRAME_HEIGHT := 6.0


## Width of a menu-bar label, including its 5.5px padding on each side.
static func bar_label_width(label: String) -> float:
	return XpFonts.measure_ui(MenuLabel.parse(label).text) + _LABEL_PADDING


## Height of a popup: a row for each item and a thin row for each separator, inside the
## border and padding.
static func popup_height(items: Array[XpMenuItem]) -> float:
	var height := _FRAME_HEIGHT
	for item in items:
		height += SEPARATOR_HEIGHT if item.is_separator else XpMetrics.MENU_ROW_HEIGHT
	return height


static func popup_width(items: Array[XpMenuItem]) -> float:
	var width := _MIN_WIDTH
	for item in items:
		if item.is_separator:
			continue
		var label_width := XpFonts.measure_ui(MenuLabel.parse(item.label).text)
		var shortcut_width := 0.0
		if not item.shortcut.is_empty():
			shortcut_width = _SHORTCUT_GAP + XpFonts.measure_ui(item.shortcut)
		width = maxf(width, _ROW_LEFT_INSET + label_width + shortcut_width + _ROW_RIGHT_INSET)
	return width
