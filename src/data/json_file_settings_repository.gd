class_name JsonFileSettingsRepository
extends SettingsRepository
## Stores settings as JSON. XP keeps them in the registry; this clone uses a file, in the
## same place and with the same keys as the Flutter version, so the settings carry over.

## The settings file, or an empty string when the system gives no place to keep settings.
## The defaults then apply on every run and nothing is written.
var file_path: String = ""


func _init(path: String = "") -> void:
	file_path = path


## %APPDATA%\xp_notepad\settings.json on Windows, otherwise
## $XDG_CONFIG_HOME/xp_notepad/settings.json (or ~/.config). A variable that is empty, or a
## relative path, is ignored, as the XDG Base Directory specification says. With no usable
## folder at all, settings are not kept: a relative guess would put the file in whatever
## folder the app was started from. [param environment] stands in for the process
## environment, and [param windows] for the operating system, in tests.
static func standard(environment: Variant = null, windows: Variant = null) -> JsonFileSettingsRepository:
	var is_windows: bool = (OS.get_name() == "Windows") if windows == null else windows
	var base := ""
	if is_windows:
		base = _absolute(_env(environment, "APPDATA"))
		if base.is_empty():
			base = _absolute(_env(environment, "USERPROFILE"))
	else:
		base = _absolute(_env(environment, "XDG_CONFIG_HOME"))
		if base.is_empty():
			var home := _absolute(_env(environment, "HOME"))
			if not home.is_empty():
				base = home.path_join(".config")
	if base.is_empty():
		return JsonFileSettingsRepository.new("")
	return JsonFileSettingsRepository.new(base.path_join("xp_notepad").path_join("settings.json"))


static func _env(environment: Variant, name: String) -> String:
	if environment is Dictionary:
		return str(environment.get(name, ""))
	return OS.get_environment(name)


static func _absolute(value: String) -> String:
	return value if not value.is_empty() and value.is_absolute_path() else ""


func load_settings() -> NotepadSettings:
	if file_path.is_empty() or not FileAccess.file_exists(file_path):
		return NotepadSettings.new()
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return NotepadSettings.new()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	# A file that is not valid UTF-8 is damaged, as one that is not valid JSON is.
	if not TextCodec._is_valid_utf8(bytes):
		return NotepadSettings.new()
	var decoded: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if decoded is Dictionary:
		return NotepadSettings.from_json(decoded)
	# A damaged file is replaced by defaults on the next save.
	return NotepadSettings.new()


## Writes a temporary file beside the settings and moves it into place, so a crash during
## the write leaves the old settings, never half of the new ones. Settings are written one
## after another, so an older save can never finish after a newer one and bring back a
## setting the user has since changed.
func save_settings(settings: NotepadSettings) -> int:
	if file_path.is_empty():
		return OK
	var json := JSON.stringify(settings.to_json(), "  ")
	var folder := file_path.get_base_dir()
	var made := DirAccess.make_dir_recursive_absolute(folder)
	if made != OK and not DirAccess.dir_exists_absolute(folder):
		return made
	# A settings file that is a symbolic link, as a dotfile manager makes it, is written
	# through to its target, so the link itself is kept.
	var target := PathLinks.resolve(file_path)
	var temporary := "%s.%d.%d.tmp" % [target, OS.get_process_id(), Time.get_ticks_usec()]
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		return FileAccess.get_open_error()
	handle.store_string(json)
	handle.flush()
	var write_error := handle.get_error()
	handle.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return write_error
	var renamed := DirAccess.rename_absolute(temporary, target)
	if renamed != OK:
		DirAccess.remove_absolute(temporary)
	return renamed
