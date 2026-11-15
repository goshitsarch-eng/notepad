extends TestCase
## The version number lives in several files, and a release that updates some of them and
## not the rest ships the wrong number. These checks make that a failing test instead.
## Port of app_info_test.dart; the single source of truth is now project.godot.

var _semantic := RegEx.create_from_string("^[0-9]+\\.[0-9]+\\.[0-9]+$")


func _read(path: String) -> String:
	var file := FileAccess.open("res://" + path, FileAccess.READ)
	if file == null:
		fail("%s cannot be read" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text


## The first capture group of [param pattern] in the file, or an empty string.
func _first_match(path: String, pattern: String) -> String:
	var hit := RegEx.create_from_string(pattern).search(_read(path))
	return "" if hit == null else hit.get_string(1)


func _project_version() -> String:
	return _first_match("project.godot", "(?m)^config/version=\"([^\"]*)\"\\s*$")


func test_project_godot_has_a_semantic_version() -> void:
	var version := _project_version()
	assert_ne(version, "", "config/version is missing from project.godot")
	assert_true(_semantic.search(version) != null, "'%s' is not a semantic x.y.z version" % version)


func test_help_about_shows_the_version_in_project_godot() -> void:
	assert_eq(AppInfo.version(), _project_version())


func test_the_flatpak_metadata_lists_this_version_as_its_newest_release() -> void:
	var first := _first_match(
		"packaging/flatpak/com.goshapps.Notepad.metainfo.xml", "<release version=\"([^\"]+)\"")
	assert_ne(first, "", "no <release> found in the metainfo")
	assert_eq(first, AppInfo.version())


func test_the_windows_installer_script_defaults_to_this_version() -> void:
	var defined := _first_match("packaging/windows/xp-notepad.iss", "#define AppVersion \"([^\"]+)\"")
	assert_ne(defined, "", "no #define AppVersion found in the installer script")
	assert_eq(defined, AppInfo.version())


func test_the_readme_states_this_version() -> void:
	assert_contains(_read("README.md"), "Version %s" % AppInfo.version())


func test_application_name_is_notepad() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Notepad")
	assert_eq(_first_match("project.godot", "(?m)^config/name=\"([^\"]*)\"\\s*$"), "Notepad")


func test_application_icons_are_configured_for_all_platforms() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/icon"), "res://icon.svg")
	assert_eq(
		ProjectSettings.get_setting("application/config/macos_native_icon"),
		"res://packaging/macos/AppIcon.icns")
	assert_eq(
		ProjectSettings.get_setting("application/config/windows_native_icon"),
		"res://packaging/windows/app_icon.ico")
	assert_true(FileAccess.file_exists("res://icon.svg"), "icon.svg exists")
	assert_true(FileAccess.file_exists("res://packaging/macos/AppIcon.icns"), "macOS AppIcon.icns exists")
	assert_true(FileAccess.file_exists("res://packaging/windows/app_icon.ico"), "Windows app_icon.ico exists")
	assert_true(FileAccess.file_exists("res://packaging/icons/com.goshapps.Notepad.svg"), "Linux SVG icon exists")
	var presets := _read("export_presets.cfg")
	assert_false(presets.contains("packaging/*"), "export_presets.cfg must not exclude native icons in packaging/")
	var desktop := _read("packaging/flatpak/com.goshapps.Notepad.desktop")
	assert_contains(desktop, "Icon=com.goshapps.Notepad")
	assert_contains(desktop, "StartupWMClass=Notepad")
	var iss := _read("packaging/windows/xp-notepad.iss")
	assert_contains(iss, "SetupIconFile=app_icon.ico")
	assert_contains(iss, "IconFilename: \"{app}\\app_icon.ico\"")
	var tex := XpIcons.app_icon_texture(32)
	assert_not_null(tex, "About dialog app icon texture loads")
	assert_eq(tex.get_width(), 32)
	assert_eq(tex.get_height(), 32)

