class_name MenuLabel
extends RefCounted
## A menu label such as "&File" or "Page Se&tup...". The character after '&' is the
## mnemonic, which is underlined while the keyboard cues are showing.

## The label without the '&' marker.
var text: String = ""
## Index into [member text] of the mnemonic character, or -1.
var mnemonic_index: int = -1


static func parse(raw: String) -> MenuLabel:
	var label := MenuLabel.new()
	var amp := raw.find("&")
	if amp < 0 or amp == raw.length() - 1:
		label.text = raw
		return label
	label.text = raw.substr(0, amp) + raw.substr(amp + 1)
	label.mnemonic_index = amp
	return label


## The lower-case mnemonic letter, used to match key presses, or an empty string.
func mnemonic() -> String:
	if mnemonic_index < 0:
		return ""
	return text[mnemonic_index].to_lower()


## Draws the label with its top left at [param top_left], underlining the mnemonic when
## [param underline] is set.
func draw(canvas: CanvasItem, top_left: Vector2, color: Color, underline: bool) -> void:
	XpDraw.text(canvas, top_left, text, color)
	if underline and mnemonic_index >= 0:
		var before := XpDraw.text_width(text.substr(0, mnemonic_index))
		var width := XpDraw.text_width(text[mnemonic_index])
		var y := floorf(top_left.y + XpFonts.ui().get_ascent(XpFonts.ui_size())) + 2.0
		canvas.draw_rect(Rect2(top_left.x + before, y, width, 1), color)
