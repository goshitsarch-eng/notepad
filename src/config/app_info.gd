class_name AppInfo
extends RefCounted
## The version shown in Help > About. It is the project's own version setting, so there is
## a single place to change it. test/test_app_info.gd checks that every file that
## repeats it (the Flatpak metadata, the Windows installer script, the README) agrees.


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
