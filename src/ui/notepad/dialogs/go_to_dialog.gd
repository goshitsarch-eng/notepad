class_name GoToDialog
extends XpDialogWindow
## Edit > Go To: a line-number box, pre-filled with the caret's line.

## A line number too long for an integer is simply a line past the end of the text, which
## goes to the last line, not a number to ignore.
const _PAST_THE_END := 0x7FFFFFFF

var request: DialogRequests.GoToRequest
var line_box: XpTextBox


func _init(go_to_request: DialogRequests.GoToRequest) -> void:
	super("Go To Line", 230.0)
	request = go_to_request
	close_requested.connect(cancel)
	line_box = XpTextBox.new("0123456789")
	line_box.accessible_name = "Line number"
	# The line number starts out selected, so typing replaces it instead of adding to it.
	line_box.set_text_selected(str(request.current_line))
	line_box.text_submitted.connect(func(_text: String) -> void: submit())
	var go := XpButton.new("Go To", true)
	go.pressed.connect(submit)
	var cancel_button := XpButton.new("Cancel")
	cancel_button.pressed.connect(cancel)
	set_content(Ui.vbox([
		Ui.label("Line Number:"), Ui.spacer(0, 4), line_box, Ui.spacer(0, 14),
		Ui.right_aligned([go, cancel_button])]))


func submit() -> void:
	var typed := line_box.text.strip_edges()
	if typed.is_empty():
		return
	var line := _PAST_THE_END if typed.length() > 15 else typed.to_int()
	request.complete(line)


func cancel() -> void:
	request.complete(null)


func focus_target() -> Control:
	return line_box
