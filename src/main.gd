extends Node
## Starts XP Notepad: loads the settings, sets up the borderless window, builds the view
## model and the screen, and opens the file named on the command line.

var view_model: NotepadViewModel
var screen: NotepadScreen


func _ready() -> void:
	var window := get_window()
	var dependencies := AppDependencies.standard(window)
	var settings := dependencies.settings.load_settings()

	# Sizes are logical pixels, as in the Flutter version, so the content is scaled to the
	# screen and the window made as many device pixels.
	var scale := maxf(DisplayServer.screen_get_scale(), 1.0)
	window.content_scale_factor = scale
	window.min_size = Vector2i(
		roundi(NotepadSettings.MINIMUM_WINDOW_WIDTH * scale), roundi(NotepadSettings.MINIMUM_WINDOW_HEIGHT * scale))
	window.size = Vector2i(roundi(settings.window_width * scale), roundi(settings.window_height * scale))
	window.borderless = true
	window.move_to_center()

	view_model = NotepadViewModel.new(dependencies, settings)
	screen = NotepadScreen.new(view_model)
	add_child(screen)
	view_model.start(_initial_path())


## The file named on the command line: after `--` when run from the editor or with Godot
## itself, and the first plain argument of the installed app.
static func _initial_path() -> String:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("-"):
			return argument
	if OS.has_feature("editor"):
		return ""
	for argument in OS.get_cmdline_args():
		if not argument.begins_with("-"):
			return argument
	return ""
