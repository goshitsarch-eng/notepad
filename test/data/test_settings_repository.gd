extends TestCase
## Port of settings_repository_test.dart. A Dart call that threw FileSystemException returns
## a Godot Error other than OK here.

var _folder: String = ""


func before_each() -> void:
	_folder = make_temp_dir()


func _settings(changes: Dictionary) -> NotepadSettings:
	return NotepadSettings.new().copy_with(changes)


# ---- where settings are kept (F-10) ----

func test_xdg_config_home_is_used_when_it_is_an_absolute_path() -> void:
	var repository := JsonFileSettingsRepository.standard(
		{"XDG_CONFIG_HOME": "/xdg", "HOME": "/home/me"}, false)
	assert_eq(repository.file_path, "/xdg/xp_notepad/settings.json")


func test_an_empty_xdg_config_home_counts_as_unset_and_does_not_write_to_the_working_folder() -> void:
	var repository := JsonFileSettingsRepository.standard(
		{"XDG_CONFIG_HOME": "", "HOME": "/home/me"}, false)
	assert_eq(repository.file_path, "/home/me/.config/xp_notepad/settings.json")


func test_a_relative_xdg_config_home_is_ignored_as_the_xdg_specification_requires() -> void:
	var repository := JsonFileSettingsRepository.standard(
		{"XDG_CONFIG_HOME": "relative/dir", "HOME": "/home/me"}, false)
	assert_eq(repository.file_path, "/home/me/.config/xp_notepad/settings.json")


func test_with_no_usable_folder_at_all_nothing_is_read_or_written() -> void:
	var repository := JsonFileSettingsRepository.standard({"XDG_CONFIG_HOME": "", "HOME": ""}, false)
	assert_eq(repository.file_path, "")
	assert_true(repository.load_settings() is NotepadSettings)
	# Must not fail, and must not create a folder in the working directory.
	assert_eq(repository.save_settings(_settings({"dark_mode": true})), OK)
	assert_false(DirAccess.dir_exists_absolute(".config"))
	assert_false(DirAccess.dir_exists_absolute("res://.config"))


func test_a_relative_home_is_ignored_too() -> void:
	var repository := JsonFileSettingsRepository.standard({"HOME": "relative"}, false)
	assert_eq(repository.file_path, "")


func test_windows_uses_appdata_then_userprofile() -> void:
	var with_appdata := JsonFileSettingsRepository.standard(
		{"APPDATA": "C:/Users/me/AppData/Roaming", "USERPROFILE": "C:/Users/me"}, true)
	assert_eq(with_appdata.file_path, "C:/Users/me/AppData/Roaming/xp_notepad/settings.json")
	var without := JsonFileSettingsRepository.standard({"APPDATA": "", "USERPROFILE": "C:/Users/me"}, true)
	assert_eq(without.file_path, "C:/Users/me/xp_notepad/settings.json")
	var neither := JsonFileSettingsRepository.standard({}, true)
	assert_eq(neither.file_path, "")


# ---- saving ----

func test_settings_survive_a_save_and_a_load() -> void:
	var repository := JsonFileSettingsRepository.new(_folder + "/xp/settings.json")
	assert_eq(repository.save_settings(_settings({"dark_mode": true, "word_wrap": false})), OK)

	var loaded := repository.load_settings()

	assert_true(loaded.dark_mode)
	assert_false(loaded.word_wrap)


func test_no_temporary_file_is_left_behind() -> void:
	var file := _folder + "/xp/settings.json"
	JsonFileSettingsRepository.new(file).save_settings(NotepadSettings.new())

	assert_eq(list_names(_folder + "/xp"), ["settings.json"])


func test_the_last_save_wins_however_many_are_made_together() -> void:
	# Saves are synchronous here, so they cannot overlap; this guards that the last one made
	# is the one that stays, and that every save in a row replaces the file.
	var repository := JsonFileSettingsRepository.new(_folder + "/xp/settings.json")
	for round_number in range(10):
		for i in range(12):
			repository.save_settings(_settings({"last_directory": "/folder/%d" % i, "dark_mode": i % 2 == 1}))
		var loaded := repository.load_settings()
		assert_eq(loaded.last_directory, "/folder/11", "round %d" % round_number)
		assert_true(loaded.dark_mode)
	assert_eq(list_names(_folder + "/xp"), ["settings.json"])


func test_a_settings_file_that_is_a_symbolic_link_is_written_through_and_the_link_kept() -> void:
	if OS.get_name() == "Windows":
		return
	var target := _folder + "/dotfiles/settings.json"
	write_text(target, "{}")
	DirAccess.make_dir_recursive_absolute(_folder + "/xp")
	var link := _folder + "/xp/settings.json"
	assert_eq(OS.execute("ln", ["-s", target, link]), 0)
	var repository := JsonFileSettingsRepository.new(link)

	assert_eq(repository.save_settings(_settings({"dark_mode": true})), OK)

	assert_true(DirAccess.open(_folder + "/xp").is_link(link), "the link must survive")
	assert_true(repository.load_settings().dark_mode)
	assert_contains(read_text(target), "\"darkMode\": true")


func test_a_failed_save_does_not_stop_the_saves_after_it_and_leaves_nothing_behind() -> void:
	# The settings folder cannot be created because a file is in the way.
	var blocker := _folder + "/blocked"
	write_text(blocker, "x")
	var failing := JsonFileSettingsRepository.new(blocker + "/settings.json")
	assert_ne(failing.save_settings(NotepadSettings.new()), OK)

	var working := JsonFileSettingsRepository.new(_folder + "/ok/settings.json")
	assert_eq(working.save_settings(_settings({"dark_mode": true})), OK)
	assert_true(working.load_settings().dark_mode)

	# A repository that has seen a failure keeps failing the same way, and keeps going.
	assert_ne(failing.save_settings(NotepadSettings.new()), OK)
	assert_ne(failing.save_settings(NotepadSettings.new()), OK)
	assert_eq(list_names(_folder), ["blocked", "ok"])
	assert_eq(read_text(blocker), "x")


func test_a_failed_write_leaves_the_old_settings() -> void:
	var file := _folder + "/xp/settings.json"
	var repository := JsonFileSettingsRepository.new(file)
	repository.save_settings(_settings({"dark_mode": true}))
	# A folder where the temporary file would go does not matter; make the target a folder so
	# that moving the finished file over it fails.
	DirAccess.remove_absolute(file)
	DirAccess.make_dir_recursive_absolute(file)

	assert_ne(repository.save_settings(_settings({"dark_mode": false})), OK)
	assert_eq(list_names(_folder + "/xp"), ["settings.json"], "no temporary file is left")


# ---- loading ----

func test_a_missing_file_gives_the_defaults() -> void:
	var repository := JsonFileSettingsRepository.new(_folder + "/none.json")
	assert_true(repository.load_settings().word_wrap)


func test_a_damaged_file_gives_the_defaults_and_the_next_save_replaces_it() -> void:
	var file := _folder + "/settings.json"
	write_text(file, "{ not json")
	var repository := JsonFileSettingsRepository.new(file)
	assert_true(repository.load_settings().word_wrap)

	repository.save_settings(_settings({"word_wrap": false}))

	assert_false(repository.load_settings().word_wrap)


func test_a_file_that_is_not_valid_utf8_gives_the_defaults() -> void:
	var file := _folder + "/settings.json"
	write_bytes(file, PackedByteArray([0xFF, 0xFE, 0x00, 0x80]))
	assert_true(JsonFileSettingsRepository.new(file).load_settings().word_wrap)


func test_a_file_whose_json_is_not_an_object_gives_the_defaults() -> void:
	var file := _folder + "/settings.json"
	write_text(file, "[1, 2, 3]")
	assert_true(JsonFileSettingsRepository.new(file).load_settings().word_wrap)


func test_the_settings_file_keeps_the_keys_of_the_flutter_version() -> void:
	var file := _folder + "/settings.json"
	var repository := JsonFileSettingsRepository.new(file)
	repository.save_settings(_settings({"dark_mode": true, "word_wrap": false, "last_directory": "/x"}))

	var json: Variant = JSON.parse_string(read_text(file))

	assert_true(json is Dictionary)
	assert_eq(json["darkMode"], true)
	assert_eq(json["wordWrap"], false)
	assert_eq(json["lastDirectory"], "/x")
