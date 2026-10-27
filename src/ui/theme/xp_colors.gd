class_name XpColors
extends RefCounted
## Luna (Windows XP blue) colours, with a dark variant. Light values come from the Luna theme
## and the measured reference used by the earlier clone. Dark values are a slate-grey
## version of the same roles.
##
## [member dark] is switched by the view model. Controls read the colours when they draw, so
## they pick up the change when the screen asks them to draw again.

## True while Dark Mode is on.
static var dark: bool = false


## A colour from an 0xAARRGGBB number.
static func argb(value: int) -> Color:
	return Color(
		float((value >> 16) & 0xFF) / 255.0,
		float((value >> 8) & 0xFF) / 255.0,
		float(value & 0xFF) / 255.0,
		float((value >> 24) & 0xFF) / 255.0)


static func _pick(light: int, dark_value: int) -> Color:
	return argb(dark_value if dark else light)


static func face() -> Color: return _pick(0xFFECE9D8, 0xFF2D2D30)
static func paper() -> Color: return _pick(0xFFFFFFFF, 0xFF1E1E1E)
static func text() -> Color: return _pick(0xFF000000, 0xFFE6E6E6)
static func gray_text() -> Color: return _pick(0xFFACA899, 0xFF7A7A7A)
static func highlight() -> Color: return _pick(0xFF316AC5, 0xFF2F5F9E)
static func highlight_text() -> Color: return argb(0xFFFFFFFF)
static func edit_border() -> Color: return _pick(0xFF7F9DB9, 0xFF4A4A52)
static func rule_dark() -> Color: return _pick(0xFFACA899, 0xFF4A4A52)
static func rule_light() -> Color: return _pick(0xFFFFFFFF, 0xFF3A3A40)
static func menu_border() -> Color: return _pick(0xFF919B9C, 0xFF5A5A62)
static func menu_shadow() -> Color: return _pick(0x4D000000, 0x66000000)
static func scroll_track() -> Color: return _pick(0xFFFBFBF9, 0xFF252527)
static func scroll_button() -> Color: return _pick(0xFFECEBE5, 0xFF3E3E42)
static func scroll_arrow() -> Color: return _pick(0xFFC9C9C2, 0xFFB5B5B5)
static func thumb_border() -> Color: return _pick(0xFF8DA4CE, 0xFF6F6F75)
static func button_border() -> Color: return _pick(0xFF003C74, 0xFF5C5C63)
static func button_default_ring() -> Color: return argb(0xFF3C8FFD)
static func button_hover_ring() -> Color: return argb(0xFFFBC761)
static func button_focus_ring() -> Color: return argb(0xFF98B8EA)
static func check_mark() -> Color: return _pick(0xFF21A121, 0xFF5FB8FF)
static func box_border() -> Color: return argb(0xFF8E8F8F)
static func caption_active() -> Color: return _pick(0xFF0050EE, 0xFF2A5C96)
static func caption_inactive() -> Color: return _pick(0xFF7A96DF, 0xFF3A4250)
static func caption_hover() -> Color: return _pick(0xFF3F7DF6, 0xFF3A6FB0)
static func caption_pressed() -> Color: return _pick(0xFF003DD7, 0xFF1B3354)
static func close_button() -> Color: return argb(0xFFD3552F)
static func close_button_hover() -> Color: return argb(0xFFE8704C)
static func close_button_pressed() -> Color: return argb(0xFFB8421F)
static func button_glyph_edge() -> Color: return argb(0xB3FFFFFF)
static func title_shadow() -> Color: return _pick(0xFF0F1089, 0xFF0B1A30)
static func title_inactive_text() -> Color: return _pick(0xFFD8E4F8, 0xFFB9C2CF)


## Window frame bands, outermost first: left edge.
static func frame_left() -> Array[Color]:
	if dark:
		return [argb(0xFF0C2442), argb(0xFF17375F), argb(0xFF245385), argb(0xFF1B4070)]
	return [argb(0xFF0019CF), argb(0xFF0831D9), argb(0xFF166AEE), argb(0xFF0855DD)]


## Window frame bands, outermost first: right and bottom edges.
static func frame_right_bottom() -> Array[Color]:
	if dark:
		return [argb(0xFF081A30), argb(0xFF0F2B4D), argb(0xFF1D4A7E), argb(0xFF2A5D93)]
	return [argb(0xFF00138C), argb(0xFF001EA1), argb(0xFF003DDD), argb(0xFF0048F1)]


static func frame_inactive() -> Array[Color]:
	if dark:
		return [argb(0xFF3A4250), argb(0xFF4B5563), argb(0xFF5A6474), argb(0xFF6B7689)]
	return [argb(0xFF7A96DF), argb(0xFFA2B8EA), argb(0xFFBFD0F2), argb(0xFFD8E4F8)]
