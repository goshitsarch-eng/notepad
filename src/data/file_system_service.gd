class_name FileSystemService
extends RefCounted
## Access to folders for the file dialogs. Tests replace it with a fake.


func home_directory() -> String:
	# An empty variable counts as unset: a start folder of '' lists the wrong place.
	for variable in ["USERPROFILE", "HOME"]:
		var value := OS.get_environment(variable)
		if not value.is_empty():
			return value
	return ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()


func file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func directory_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


## Folders first, then matching files, each sorted by name. Hidden entries are skipped,
## and so is any single entry that cannot be read. Fails with a [FileError] when the
## folder itself cannot be listed, so the dialog can say why instead of showing nothing.
## On success the value is an Array of [DirectoryEntry].
func list_directory(directory: String, filter: FileTypeFilter) -> Result:
	var access := DirAccess.open(directory)
	if access == null:
		return Result.failure(FileError.from_godot(DirAccess.get_open_error(), directory))
	access.include_hidden = false
	access.include_navigational = false
	var listing_error := access.list_dir_begin()
	if listing_error != OK:
		return Result.failure(FileError.from_godot(listing_error, directory))
	var names: Array[String] = []
	var name := access.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			names.append(name)
		name = access.get_next()
	access.list_dir_end()

	var folders: Array = []
	var files: Array = []
	var examined := 0
	var failures := 0
	var first_failure: FileError = null
	for entry_name in names:
		var path := directory.path_join(entry_name)
		var is_folder := DirAccess.dir_exists_absolute(path)
		# The listing does not say files from folders, but a file the filter hides needs
		# no further system call.
		if not is_folder and not filter.matches(entry_name):
			continue
		examined += 1
		if is_folder:
			folders.append(DirectoryEntry.new(entry_name, path, true, 0, FileAccess.get_modified_time(path)))
			continue
		if not FileAccess.file_exists(path):
			# A link whose target is gone has nothing to show and is left out. Any other
			# entry that cannot be examined, most often for want of the search permission,
			# is a failure.
			if access.is_link(path):
				continue
			failures += 1
			if first_failure == null:
				first_failure = FileError.make(
					"Its entries cannot be examined. Check the folder's permissions", path)
			continue
		files.append(DirectoryEntry.new(
			entry_name, path, false, FileAccess.get_size(path), FileAccess.get_modified_time(path)))
	# A folder whose names can be read but whose entries cannot be examined at all, such
	# as one without the search permission, is not empty. Say so, as for a folder that
	# cannot be listed. A single bad entry among good ones is skipped quietly.
	if first_failure != null and failures == examined:
		return Result.failure(first_failure)
	return Result.success(_sorted(folders) + _sorted(files))


## Sorts on a lower-cased name made once per entry, not once per comparison.
static func _sorted(entries: Array) -> Array:
	var keyed: Array = []
	for entry in entries:
		keyed.append([(entry as DirectoryEntry).name.to_lower(), entry])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	for pair in keyed:
		out.append(pair[1])
	return out
