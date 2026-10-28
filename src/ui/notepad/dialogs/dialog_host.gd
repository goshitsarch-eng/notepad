class_name ModalDialogHost
extends Control
## Shows the blocking dialog for a request centred over the window. The barrier keeps clicks
## from reaching the text until the dialog is answered.

var request: DialogRequests.Request
var dialog: XpDialogWindow


func _init(modal_request: DialogRequests.Request, view_model: NotepadViewModel) -> void:
	request = modal_request
	mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.anchor(self, Vector4(0, 0, 1, 1), Vector4.ZERO)
	if request is DialogRequests.MessageRequest:
		dialog = MessageDialog.new(request)
	elif request is DialogRequests.GoToRequest:
		dialog = GoToDialog.new(request)
	elif request is DialogRequests.FontRequest:
		dialog = FontDialog.new(request)
	elif request is DialogRequests.PageSetupRequest:
		dialog = PageSetupDialog.new(request)
	elif request is DialogRequests.AboutRequest:
		dialog = AboutDialog.new(request)
	elif request is DialogRequests.HelpRequest:
		dialog = HelpDialog.new(request)
	elif request is DialogRequests.FileRequest:
		dialog = OpenSaveDialog.new(request, view_model.file_system)
	add_child(dialog)


func _ready() -> void:
	XpAccessibility.modal_root = self
	XpAccessibility.refresh_all(get_tree())
	resized.connect(_place)
	# The size of the window is not known until the first frame has been laid out.
	_place.call_deferred()
	# Each dialog opens with its own field focused, so typing goes to it and not the text.
	XpDraw.keyboard_active = true
	(dialog.call("focus_target") as Control).grab_focus()


func _exit_tree() -> void:
	if XpAccessibility.modal_root == self:
		XpAccessibility.modal_root = null
		XpAccessibility.refresh_all(get_tree())


func _place() -> void:
	dialog.place(size)


## Escape cancels whichever dialog has focus, even when focus is on the dialog itself rather
## than one of its fields. A cancelled request completes with null.
func cancel() -> void:
	dialog.call("cancel")
