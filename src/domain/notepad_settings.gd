class_name NotepadSettings
extends RefCounted
## Everything Notepad remembers between runs.

## The smallest size the window may have, in logical pixels. The menu bar, caption and
## status bar stop fitting below this, and so does the tallest menu: the Edit popup is
## drawn inside the window, so a window shorter than it would hide the last items.
const MINIMUM_WINDOW_WIDTH := 400.0
const MINIMUM_WINDOW_HEIGHT := 310.0

## The largest saved window size. Larger values in the settings file are clamped to this,
## so the window cannot open off the screen.
const _MAXIMUM_SAVED_WINDOW_SIDE := 8192.0
const _MAXIMUM_SAVED_WINDOW_COORD := 32768.0
const MINIMUM_UI_SCALE := 0.5
const MAXIMUM_UI_SCALE := 4.0

var word_wrap: bool = true
## The View > Status Bar setting. The bar is hidden while word wrap is on, as in XP.
var status_bar_visible: bool = true
var font: EditorFont = EditorFont.new()
var page_setup: PageSetup = PageSetup.new()
## The folder the file dialogs start in, or an empty string for the home folder.
var last_directory: String = ""
var window_width: float = 600.0
var window_height: float = 404.0
## The last normal window position on screen (as iWindowPosX and iWindowPosY in XP), or null
## when no position has been saved yet.
var window_x: Variant = null
var window_y: Variant = null
var dark_mode: bool = false
## Manual UI scale factor override (0.5 to 4.0), or 0.0 to follow the display's HiDPI scale.
var ui_scale: float = 0.0


func has_window_position() -> bool:
	return window_x != null and window_y != null


func copy_with(changes: Dictionary) -> NotepadSettings:
	var copy := NotepadSettings.new()
	copy.word_wrap = changes.get("word_wrap", word_wrap)
	copy.status_bar_visible = changes.get("status_bar_visible", status_bar_visible)
	copy.font = changes.get("font", font)
	copy.page_setup = changes.get("page_setup", page_setup)
	copy.last_directory = changes.get("last_directory", last_directory)
	copy.window_width = changes.get("window_width", window_width)
	copy.window_height = changes.get("window_height", window_height)
	copy.window_x = changes.get("window_x", window_x) if changes.has("window_x") else window_x
	copy.window_y = changes.get("window_y", window_y) if changes.has("window_y") else window_y
	copy.dark_mode = changes.get("dark_mode", dark_mode)
	copy.ui_scale = changes.get("ui_scale", ui_scale)
	return copy


func to_json() -> Dictionary:
	var data := {
		"wordWrap": word_wrap,
		"statusBarVisible": status_bar_visible,
		"font": font.to_json(),
		"pageSetup": page_setup.to_json(),
		"lastDirectory": last_directory if not last_directory.is_empty() else null,
		"windowWidth": window_width,
		"windowHeight": window_height,
		"darkMode": dark_mode,
	}
	if window_x != null and window_y != null:
		data["windowX"] = int(window_x)
		data["windowY"] = int(window_y)
	if ui_scale > 0.0:
		data["uiScale"] = ui_scale
	return data


static func from_json(json: Dictionary) -> NotepadSettings:
	var settings := NotepadSettings.new()
	settings.word_wrap = SettingsValues.flag(json.get("wordWrap"), true)
	settings.status_bar_visible = SettingsValues.flag(json.get("statusBarVisible"), true)
	var font_json: Variant = json.get("font")
	settings.font = EditorFont.from_json(font_json) if font_json is Dictionary else EditorFont.new()
	var setup_json: Variant = json.get("pageSetup")
	settings.page_setup = PageSetup.from_json(setup_json) if setup_json is Dictionary else PageSetup.new()
	settings.last_directory = SettingsValues.text(json.get("lastDirectory"), "")
	settings.window_width = _window_side(json.get("windowWidth"), 600.0, MINIMUM_WINDOW_WIDTH)
	settings.window_height = _window_side(json.get("windowHeight"), 404.0, MINIMUM_WINDOW_HEIGHT)
	var parsed_x: Variant = _window_coord(json.get("windowX"))
	var parsed_y: Variant = _window_coord(json.get("windowY"))
	if parsed_x != null and parsed_y != null:
		settings.window_x = parsed_x
		settings.window_y = parsed_y
	settings.dark_mode = SettingsValues.flag(json.get("darkMode"), false)
	settings.ui_scale = _scale_value(json.get("uiScale"))
	return settings


## A saved window side, kept between the minimum and a sane maximum. Anything else falls
## back to the default.
static func _window_side(value: Variant, fallback: float, minimum: float) -> float:
	var side := SettingsValues.number(value, fallback)
	if not is_finite(side):
		return fallback
	return clampf(side, minimum, _MAXIMUM_SAVED_WINDOW_SIDE)


static func _window_coord(value: Variant) -> Variant:
	if not (value is int or value is float):
		return null
	var number := float(value)
	if not is_finite(number) or absf(number) > _MAXIMUM_SAVED_WINDOW_COORD:
		return null
	return roundi(number)


static func _scale_value(value: Variant) -> float:
	if not (value is int or value is float):
		return 0.0
	var number := float(value)
	if not is_finite(number) or number < MINIMUM_UI_SCALE or number > MAXIMUM_UI_SCALE:
		return 0.0
	return number
