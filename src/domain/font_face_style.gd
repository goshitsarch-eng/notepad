class_name FontFaceStyle
extends RefCounted
## Font styles offered by the Font dialog's "Font style" list.

enum { REGULAR, ITALIC, BOLD, BOLD_ITALIC }

const ALL: Array[int] = [REGULAR, ITALIC, BOLD, BOLD_ITALIC]

## The names the settings file stores, which are the ones earlier versions wrote.
const _NAMES: Array[String] = ["regular", "italic", "bold", "boldItalic"]
const _LABELS: Array[String] = ["Regular", "Italic", "Bold", "Bold Italic"]


static func label(style: int) -> String:
	return _LABELS[style]


static func style_name(style: int) -> String:
	return _NAMES[style]


## The style called [param style_name_value], or [param fallback] for any other value.
static func from_name(style_name_value: Variant, fallback: int = REGULAR) -> int:
	if style_name_value is String:
		var index := _NAMES.find(style_name_value)
		if index >= 0:
			return index
	return fallback


static func is_bold(style: int) -> bool:
	return style == BOLD or style == BOLD_ITALIC


static func is_italic(style: int) -> bool:
	return style == ITALIC or style == BOLD_ITALIC
