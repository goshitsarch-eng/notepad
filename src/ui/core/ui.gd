class_name Ui
extends RefCounted
## Small builders for the layouts of the dialogs, which are made in code.


static func vbox(children: Array = [], separation: int = 0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in children:
		box.add_child(child)
	return box


static func hbox(children: Array = [], separation: int = 0) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in children:
		box.add_child(child)
	return box


## Empty room of a fixed size.
static func spacer(width: float, height: float = 0.0) -> Control:
	var room := Control.new()
	room.custom_minimum_size = Vector2(width, height)
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return room


## Makes [param control] take the room left over in its row or column, in proportion to
## [param ratio] when several do.
static func expand(control: Control, ratio: float = 1.0) -> Control:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = ratio
	return control


static func expand_vertically(control: Control) -> Control:
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return control


static func label(content: String, bold: bool = false) -> XpLabel:
	return XpLabel.new(content, bold)


## A label that wraps at [param width], with its height worked out from the text, because an
## engine label cannot say how tall it is before it is laid out.
static func wrapped_label(content: String, width: float, bold: bool = false) -> XpLabel:
	var wrapped := XpLabel.new(content, bold)
	wrapped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var font := XpFonts.ui_bold() if bold else XpFonts.ui()
	var measured := font.get_multiline_string_size(
		content, HORIZONTAL_ALIGNMENT_LEFT, width, XpFonts.ui_size())
	wrapped.custom_minimum_size = Vector2(width, ceilf(measured.y))
	return wrapped


## Centres a row of controls.
static func centered(control: Control) -> Control:
	var row := hbox([control])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	return row


## Puts a row of controls at the right.
static func right_aligned(children: Array, separation: int = 6) -> HBoxContainer:
	var row := hbox(children, separation)
	row.alignment = BoxContainer.ALIGNMENT_END
	return row


## A caption above a control, with 4 pixels between them.
static func captioned(caption: String, control: Control) -> VBoxContainer:
	return vbox([label(caption), spacer(0, 4), control])


## Pins [param control] inside its parent: [param anchors] are the left, top, right and
## bottom anchors (0 to 1), and [param offsets] the distances from them in pixels. The engine
## keeps the control there when the parent changes size, which a layout done in a resize
## notification cannot promise for a control that has only just been added.
static func anchor(control: Control, anchors: Vector4, offsets: Vector4) -> void:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
