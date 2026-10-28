class_name AboutDialog
extends XpDialogWindow
## Help > About Notepad. It names this clone and carries no Microsoft branding.

var request: DialogRequests.AboutRequest
var _ok: XpButton


func _init(about_request: DialogRequests.AboutRequest) -> void:
	super("About Notepad", 330.0)
	request = about_request
	close_requested.connect(cancel)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void: XpIcons.draw_notepad(icon, Vector2.ZERO, 32.0))
	var details := Ui.vbox([
		Ui.label("Notepad", true),
		Ui.spacer(0, 2),
		Ui.label("Version %s" % AppInfo.version()),
		Ui.spacer(0, 6),
		Ui.wrapped_label("An unofficial Godot recreation of Windows XP Notepad.", 330.0 - 22.0 - 44.0),
		Ui.spacer(0, 4),
		Ui.label("Not affiliated with Microsoft."),
	])
	_ok = XpButton.new("OK", true)
	_ok.pressed.connect(cancel)
	set_content(Ui.vbox([
		Ui.hbox([icon, Ui.spacer(12), details]), Ui.spacer(0, 16), Ui.centered(_ok)]))


## Escape, Enter and the close button all close the box.
func cancel() -> void:
	request.complete(true)


func focus_target() -> Control:
	return _ok
