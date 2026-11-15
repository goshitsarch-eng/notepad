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
	if dependencies.window is GodotWindowService:
		(dependencies.window as GodotWindowService)._ui_scale_override = settings.ui_scale
	var scale := GodotWindowService.detect_scale(window.current_screen, settings.ui_scale)
	window.content_scale_factor = scale
	window.min_size = Vector2i(
		roundi(NotepadSettings.MINIMUM_WINDOW_WIDTH * scale), roundi(NotepadSettings.MINIMUM_WINDOW_HEIGHT * scale))
	window.size = Vector2i(roundi(settings.window_width * scale), roundi(settings.window_height * scale))
	window.borderless = true
	if not Engine.is_embedded_in_editor():
		if settings.has_window_position():
			window.position = GodotWindowService.clamp_to_usable_screen(
				Vector2i(roundi(settings.window_x), roundi(settings.window_y)),
				window.size, window.current_screen)
		else:
			window.move_to_center()

	view_model = NotepadViewModel.new(dependencies, settings)
	screen = NotepadScreen.new(view_model)
	add_child(screen)
	var cmd := _command_line_options()
	view_model.start(cmd["path"], cmd["encoding"], cmd["print"])


## Parses the command line for XP Notepad switches (/A for ANSI, /W for Unicode, /P for
## Print-and-exit, or their hyphenated equivalents) and the file path to open.
static func parse_command_line(args: PackedStringArray) -> Dictionary:
	var path := ""
	var encoding: int = FileEncoding.DETECT
	var print_flag := false
	for argument in args:
		var lower := argument.to_lower()
		if lower in ["/a", "-a", "--ansi"]:
			encoding = FileEncoding.ANSI
		elif lower in ["/w", "-w", "--unicode"]:
			encoding = FileEncoding.UNICODE
		elif lower in ["/p", "-p", "--print"]:
			print_flag = true
		elif not argument.begins_with("-") and path.is_empty():
			path = argument
	return {
		"path": path,
		"encoding": encoding,
		"print": print_flag,
	}


static func _command_line_options() -> Dictionary:
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		return parse_command_line(user_args)
	if OS.has_feature("editor"):
		return parse_command_line(PackedStringArray())
	return parse_command_line(OS.get_cmdline_args())


## The file named on the command line: after `--` when run from the editor or with Godot
## itself, and the first plain argument of the installed app.
static func _initial_path() -> String:
	return _command_line_options()["path"]
