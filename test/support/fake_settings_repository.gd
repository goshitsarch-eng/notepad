class_name FakeSettingsRepository
extends SettingsRepository
## Keeps the last saved settings in memory.

var saved: NotepadSettings = null
var save_count := 0


func load_settings() -> NotepadSettings:
	return saved if saved != null else NotepadSettings.new()


func save_settings(settings: NotepadSettings) -> int:
	saved = settings
	save_count += 1
	return OK
