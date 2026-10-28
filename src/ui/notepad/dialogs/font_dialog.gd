class_name FontDialog
extends XpDialogWindow
## Format > Font: family, style and size lists, with a sample line.

var request: DialogRequests.FontRequest
var family_list: XpListBox
var style_list: XpListBox
var size_list: XpListBox
var size_box: XpTextBox
var script_combo: XpComboBox
var error_label: XpLabel
var sample: Control

var _family: String
var _style: int
var _size: float


func _init(font_request: DialogRequests.FontRequest) -> void:
	super("Font", 500.0)
	request = font_request
	close_requested.connect(cancel)
	_family = request.initial.family
	_style = request.initial.style
	_size = request.initial.size_points

	family_list = XpListBox.new(PackedStringArray(EditorFont.FAMILIES), 150.0)
	family_list.accessible_name = "Font"
	family_list.selected = EditorFont.FAMILIES.find(_family)
	family_list.changed.connect(func(index: int) -> void:
		_family = EditorFont.FAMILIES[index]
		sample.queue_redraw())

	var style_labels := PackedStringArray()
	for style in FontFaceStyle.ALL:
		style_labels.append(FontFaceStyle.label(style))
	style_list = XpListBox.new(style_labels, 150.0)
	style_list.accessible_name = "Font style"
	style_list.selected = FontFaceStyle.ALL.find(_style)
	style_list.changed.connect(func(index: int) -> void:
		_style = FontFaceStyle.ALL[index]
		sample.queue_redraw())

	var size_labels := PackedStringArray()
	for size in EditorFont.SIZES:
		size_labels.append(str(size))
	size_list = XpListBox.new(size_labels, 150.0)
	size_list.accessible_name = "Size"
	size_list.selected = _size_index(_size)
	size_list.changed.connect(func(index: int) -> void: _pick_size(float(EditorFont.SIZES[index])))

	size_box = XpTextBox.new("0123456789.")
	size_box.accessible_name = "Size"
	size_box.text = _format(_size)
	size_box.text_submitted.connect(_typed_size)

	var family_column := Ui.expand(Ui.captioned("Font:", family_list), 7.0)
	var style_column := Ui.expand(Ui.captioned("Font style:", style_list), 5.0)
	var size_column := Ui.expand(Ui.vbox([
		Ui.label("Size:"), Ui.spacer(0, 4), size_box, Ui.spacer(0, 4), size_list]), 3.0)
	var ok := XpButton.new("OK", true)
	ok.pressed.connect(submit)
	var cancel_button := XpButton.new("Cancel")
	cancel_button.pressed.connect(cancel)
	var buttons := Ui.vbox([ok, Ui.spacer(0, 6), cancel_button])
	var lists := Ui.hbox([
		family_column, Ui.spacer(12), style_column, Ui.spacer(12), size_column, Ui.spacer(12), buttons])

	sample = Control.new()
	sample.custom_minimum_size = Vector2(0, 40)
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sample.clip_contents = true
	sample.draw.connect(_draw_sample)
	var sample_group := Ui.expand(XpGroupBox.new("Sample", sample))

	# The editor draws every font the same way and has no character set to pick, so the box
	# shows the one script and cannot be opened.
	script_combo = XpComboBox.new(PackedStringArray(["Western"]), 120.0)
	script_combo.enabled = false
	script_combo.accessible_name = "Script"
	var script_column := Ui.vbox([Ui.label("Script:"), Ui.spacer(0, 4), script_combo])
	script_column.custom_minimum_size = Vector2(120, 0)
	var bottom := Ui.hbox([sample_group, Ui.spacer(12), script_column])
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN

	error_label = Ui.label("")
	error_label.visible = false
	set_content(Ui.vbox([lists, Ui.spacer(0, 10), bottom, Ui.spacer(0, 8), error_label]))


func _ready() -> void:
	family_list.center_selection()
	style_list.center_selection()
	size_list.center_selection()


func _size_index(points: float) -> int:
	for index in range(EditorFont.SIZES.size()):
		if float(EditorFont.SIZES[index]) == points:
			return index
	return -1


static func _format(points: float) -> String:
	return "%d" % int(points) if points == roundf(points) else str(points)


func _range_message() -> String:
	return "Enter a size from %d to %d points." % [
		int(EditorFont.MINIMUM_SIZE_POINTS), int(EditorFont.MAXIMUM_SIZE_POINTS)]


## The size in the box, or -1 when it is empty or outside the range the dialog accepts.
func _parse_size(text: String) -> float:
	var trimmed := text.strip_edges()
	if not trimmed.is_valid_float():
		return -1.0
	var parsed := trimmed.to_float()
	if parsed < EditorFont.MINIMUM_SIZE_POINTS or parsed > EditorFont.MAXIMUM_SIZE_POINTS:
		return -1.0
	return parsed


## Enter in the Size box applies the typed size to the list and the sample at once.
func _typed_size(text: String) -> void:
	var parsed := _parse_size(text)
	if parsed < 0.0:
		_show_error(_range_message())
		return
	_size = parsed
	size_list.selected = _size_index(_size)
	_clear_error()
	sample.queue_redraw()


func _pick_size(points: float) -> void:
	_size = points
	size_box.text = _format(points)
	_clear_error()
	sample.queue_redraw()


## OK uses whatever the Size box holds, so a size typed without pressing Enter counts. A size
## outside the range keeps the dialog open and says why.
func submit() -> void:
	var parsed := _parse_size(size_box.text)
	if parsed < 0.0:
		_show_error(_range_message())
		size_box.grab_focus()
		return
	request.complete(EditorFont.new(_family, parsed, _style))


func cancel() -> void:
	request.complete(null)


func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true
	update_minimum_size()
	place(_area_size())


func _clear_error() -> void:
	error_label.visible = false
	update_minimum_size()


func focus_target() -> Control:
	# The family list opens with focus, so the arrow keys work at once.
	return family_list


func _draw_sample() -> void:
	var font := EditorFont.new(_family, _size, _style)
	var face := XpFonts.editor(font)
	var pixels := XpFonts.editor_size(font)
	var width := face.get_string_size("AaBbYyZz", HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var height := face.get_height(pixels)
	var box := sample.size
	var origin := Vector2(floorf((box.x - width) / 2.0), floorf((box.y - height) / 2.0) + face.get_ascent(pixels))
	sample.draw_string(face, origin, "AaBbYyZz", HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, XpColors.text())
