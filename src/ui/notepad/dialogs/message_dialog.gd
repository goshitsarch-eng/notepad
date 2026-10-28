class_name MessageDialog
extends XpDialogWindow
## The XP message box: an icon, the message, and a centred row of buttons. The first button is
## the default. Escape and the close button choose the cancelling answer.

var request: DialogRequests.MessageRequest
var _buttons: Array[XpButton] = []


func _init(message_request: DialogRequests.MessageRequest) -> void:
	super(message_request.title, 340.0)
	request = message_request
	alert = true
	close_requested.connect(cancel)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kind := XpIcons.MessageKind.INFORMATION
	match request.icon:
		DialogRequests.MessageIcon.WARNING:
			kind = XpIcons.MessageKind.WARNING
		DialogRequests.MessageIcon.ERROR:
			kind = XpIcons.MessageKind.ERROR
	icon.draw.connect(func() -> void: XpIcons.draw_message(icon, Vector2.ZERO, kind))
	var message := Ui.wrapped_label(request.text, 340.0 - 22.0 - 32.0 - 12.0)
	var top := Ui.hbox([icon, Ui.spacer(12), message])

	var row := Ui.hbox([], 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for index in range(request.choices.size()):
		var choice := request.choices[index]
		var button := XpButton.new(_label(choice), index == 0)
		button.pressed.connect(func() -> void: request.complete(choice))
		_buttons.append(button)
		row.add_child(button)
	set_content(Ui.vbox([top, Ui.spacer(0, 16), row]))


## The answer that Escape and the close button give.
func cancel_choice() -> int:
	var choices := request.choices
	if choices.has(DialogRequests.MessageChoice.CANCEL):
		return DialogRequests.MessageChoice.CANCEL
	if choices.has(DialogRequests.MessageChoice.NO):
		return DialogRequests.MessageChoice.NO
	return choices[0]


func cancel() -> void:
	request.complete(cancel_choice())


func focus_target() -> Control:
	return _buttons[0]


func buttons() -> Array[XpButton]:
	return _buttons


static func _label(choice: int) -> String:
	match choice:
		DialogRequests.MessageChoice.YES:
			return "Yes"
		DialogRequests.MessageChoice.NO:
			return "No"
		DialogRequests.MessageChoice.CANCEL:
			return "Cancel"
	return "OK"
