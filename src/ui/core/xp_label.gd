class_name XpLabel
extends Label
## Text in the XP interface font. It follows Dark Mode when [method xp_theme_changed] is called.

var gray: bool = false
var bold: bool = false


func _init(content: String = "", bold_text: bool = false) -> void:
	text = content
	bold = bold_text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()


func xp_theme_changed() -> void:
	_apply()


func set_gray(value: bool) -> void:
	gray = value
	_apply()


func _apply() -> void:
	add_theme_font_override("font", XpFonts.ui_bold() if bold else XpFonts.ui())
	add_theme_font_size_override("font_size", XpFonts.ui_size())
	add_theme_color_override("font_color", XpColors.gray_text() if gray else XpColors.text())
	add_theme_constant_override("line_spacing", 0)
	# The label is as tall as its font, with no padding of its own.
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
