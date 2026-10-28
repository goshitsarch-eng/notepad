class_name PageSetupDialog
extends XpDialogWindow
## File > Page Setup: header and footer text, and margins in inches.

var request: DialogRequests.PageSetupRequest
var header_box: XpTextBox
var footer_box: XpTextBox
var left_box: XpTextBox
var top_box: XpTextBox
var right_box: XpTextBox
var bottom_box: XpTextBox
var error_label: XpLabel


func _init(setup_request: DialogRequests.PageSetupRequest) -> void:
	super("Page Setup", 380.0)
	request = setup_request
	close_requested.connect(cancel)
	var initial := request.initial
	header_box = _box(initial.header, "Header")
	footer_box = _box(initial.footer, "Footer")
	left_box = _margin_box(initial.left_inches, "Left margin")
	top_box = _margin_box(initial.top_inches, "Top margin")
	right_box = _margin_box(initial.right_inches, "Right margin")
	bottom_box = _margin_box(initial.bottom_inches, "Bottom margin")
	error_label = Ui.label("")
	error_label.visible = false

	var margins := Ui.vbox([
		Ui.hbox([_margin_label("Left:"), left_box, Ui.spacer(24), _margin_label("Right:"), right_box]),
		Ui.spacer(0, 6),
		Ui.hbox([_margin_label("Top:"), top_box, Ui.spacer(24), _margin_label("Bottom:"), bottom_box]),
	])
	var fields := Ui.vbox([
		_labeled("Header:", header_box), Ui.spacer(0, 6), _labeled("Footer:", footer_box),
		Ui.spacer(0, 10), XpGroupBox.new("Margins (inches)", margins),
		Ui.spacer(0, 10), error_label])
	Ui.expand(fields)
	var ok := XpButton.new("OK", true)
	ok.pressed.connect(submit)
	var cancel_button := XpButton.new("Cancel")
	cancel_button.pressed.connect(cancel)
	var buttons := Ui.vbox([ok, Ui.spacer(0, 6), cancel_button])
	set_content(Ui.hbox([fields, Ui.spacer(12), buttons]))


func _box(initial: String, name: String) -> XpTextBox:
	var box := XpTextBox.new()
	box.text = initial
	box.accessible_name = name
	box.text_submitted.connect(func(_text: String) -> void: submit())
	Ui.expand(box)
	return box


func _margin_box(inches: float, name: String) -> XpTextBox:
	var box := XpTextBox.new("0123456789.", 60.0)
	box.text = _inches(inches)
	box.accessible_name = name
	box.text_submitted.connect(func(_text: String) -> void: submit())
	return box


## A margin the way the dialog shows it: a whole number of inches has no decimals.
static func _inches(value: float) -> String:
	return str(value)


func _margin_label(label: String) -> Control:
	var holder := Ui.label(label)
	holder.custom_minimum_size = Vector2(46, 0)
	return holder


func _labeled(label: String, field: Control) -> Control:
	var holder := Ui.label(label)
	holder.custom_minimum_size = Vector2(56, 0)
	return Ui.hbox([holder, field])


## Checks the entries. A bad entry keeps the dialog open and says what is wrong, rather than
## quietly keeping the old value.
func submit() -> void:
	var entries: Array[String] = [
		left_box.text.strip_edges(), top_box.text.strip_edges(),
		right_box.text.strip_edges(), bottom_box.text.strip_edges()]
	for entry in entries:
		if not entry.is_valid_float():
			_show_error("Enter each margin as a number of inches.")
			return
	var setup := request.initial.copy_with({
		"header": header_box.text,
		"footer": footer_box.text,
		"left_inches": entries[0].to_float(),
		"top_inches": entries[1].to_float(),
		"right_inches": entries[2].to_float(),
		"bottom_inches": entries[3].to_float(),
	})
	var problem := setup.margin_problem()
	if not problem.is_empty():
		_show_error(problem)
		return
	request.complete(setup)


func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true
	update_minimum_size()
	place(_area_size())


func cancel() -> void:
	request.complete(null)


func focus_target() -> Control:
	return header_box
