class_name SettingsRepository
extends RefCounted
## Source of truth for the settings that survive between runs. This base class keeps
## nothing; tests use it as a fake and [JsonFileSettingsRepository] is the real one.


func load_settings() -> NotepadSettings:
	return NotepadSettings.new()


## Returns an Error: OK, or why the settings could not be kept.
func save_settings(_settings: NotepadSettings) -> int:
	return OK
