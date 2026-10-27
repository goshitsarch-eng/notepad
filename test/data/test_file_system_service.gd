extends TestCase
## Port of file_system_service_test.dart. A Dart exception (FileSystemException,
## PathNotFoundException) is a failed Result whose error is a FileError.

var _service := FileSystemService.new()
var _folder: String = ""


func before_each() -> void:
	_folder = make_temp_dir()


func after_each() -> void:
	# A folder the test made unreadable has to be opened up before it can be removed.
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["-R", "u+rwx", _folder])


func _names(entries: Array) -> Array:
	var names: Array = []
	for entry in entries:
		names.append((entry as DirectoryEntry).name)
	return names


func _make_folder(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _is_root() -> bool:
	var output: Array = []
	OS.execute("id", ["-u"], output)
	return output.size() > 0 and str(output[0]).strip_edges() == "0"


func test_folders_come_first_then_files_each_sorted_without_regard_to_case() -> void:
	write_text(_folder + "/banana.txt", "b")
	write_text(_folder + "/Apple.txt", "a")
	_make_folder(_folder + "/zeta")
	_make_folder(_folder + "/Alpha")

	var result := _service.list_directory(_folder, FileTypeFilter.text_documents())

	assert_true(result.ok)
	var entries: Array = result.value
	assert_eq(_names(entries), ["Alpha", "zeta", "Apple.txt", "banana.txt"])
	assert_true((entries.front() as DirectoryEntry).is_directory)
	assert_eq((entries.back() as DirectoryEntry).size, 1)


func test_hidden_entries_and_files_the_filter_hides_are_left_out() -> void:
	write_text(_folder + "/.hidden.txt", "h")
	write_text(_folder + "/notes.txt", "n")
	write_text(_folder + "/photo.png", "p")
	_make_folder(_folder + "/.git")

	assert_eq(_names(_service.list_directory(_folder, FileTypeFilter.text_documents()).value), ["notes.txt"])
	assert_eq(_names(_service.list_directory(_folder, FileTypeFilter.all_files()).value), ["notes.txt", "photo.png"])


func test_a_folder_with_hundreds_of_entries_lists_completely_and_in_order() -> void:
	for i in range(400):
		write_text(_folder + "/file%03d.txt" % i, str(i))

	var result := _service.list_directory(_folder, FileTypeFilter.text_documents())

	assert_true(result.ok)
	var entries: Array = result.value
	assert_eq(entries.size(), 400)
	assert_eq((entries.front() as DirectoryEntry).name, "file000.txt")
	assert_eq((entries.back() as DirectoryEntry).name, "file399.txt")


func test_a_link_to_nothing_is_left_out_and_does_not_hide_the_rest_f_11() -> void:
	if OS.get_name() == "Windows":
		skip("symbolic links need extra privilege on Windows")
		return
	write_text(_folder + "/good.txt", "g")
	# A link to nothing: listing it works, and examining it finds nothing there.
	assert_eq(OS.execute("ln", ["-s", _folder + "/gone", _folder + "/dangling.txt"]), 0)
	_make_folder(_folder + "/sub")

	var result := _service.list_directory(_folder, FileTypeFilter.text_documents())

	assert_true(result.ok)
	assert_eq(_names(result.value), ["sub", "good.txt"])


func test_a_folder_that_does_not_exist_reports_it_instead_of_listing_nothing_f_11() -> void:
	var result := _service.list_directory(_folder + "/missing", FileTypeFilter.text_documents())

	assert_false(result.ok)
	assert_true(result.error is FileError)
	assert_eq((result.error as FileError).kind, FileError.Kind.NOT_FOUND)


func test_a_folder_that_cannot_be_read_reports_why_instead_of_listing_nothing_f_11() -> void:
	if OS.get_name() == "Windows":
		return
	var locked := _folder + "/locked"
	_make_folder(locked)
	write_text(locked + "/inside.txt", "i")
	OS.execute("chmod", ["000", locked])
	# Root can read anything, which makes the folder readable and this check moot.
	if _is_root() or DirAccess.open(locked) != null:
		skip("root ignores permissions (running as a user that can read every folder)")
		return

	var result := _service.list_directory(locked, FileTypeFilter.text_documents())

	assert_false(result.ok)
	assert_true(result.error is FileError)
	assert_false(FileError.describe(result.error).is_empty())


func test_a_folder_that_can_be_read_but_not_searched_reports_it_instead_of_listing_nothing_f_11() -> void:
	if OS.get_name() == "Windows":
		return
	# The case from the first audit: the names can be listed, but no entry can be examined.
	var closed := _folder + "/closed"
	_make_folder(closed)
	write_text(closed + "/inside.txt", "i")
	OS.execute("chmod", ["400", closed])
	if _is_root() or FileAccess.file_exists(closed + "/inside.txt"):
		skip("root ignores permissions (running as a user that can search every folder)")
		return

	var result := _service.list_directory(closed, FileTypeFilter.text_documents())

	assert_false(result.ok)
	assert_true(result.error is FileError)


func test_directory_exists_tells_folders_from_files_and_from_nothing() -> void:
	var file := _folder + "/a.txt"
	write_text(file, "a")

	assert_true(_service.directory_exists(_folder))
	assert_false(_service.directory_exists(file))
	assert_false(_service.directory_exists(_folder + "/nope"))
	assert_true(_service.file_exists(file))
	assert_false(_service.file_exists(_folder))


func test_the_home_folder_is_never_empty() -> void:
	assert_false(_service.home_directory().is_empty())


# ---- Extra guards for the Godot version ----

func test_an_empty_home_variable_counts_as_unset() -> void:
	# home_directory reads the process environment, so set and restore it.
	var saved_profile := OS.get_environment("USERPROFILE")
	var saved_home := OS.get_environment("HOME")
	OS.set_environment("USERPROFILE", "")
	OS.set_environment("HOME", "")
	var home := _service.home_directory()
	OS.set_environment("USERPROFILE", saved_profile)
	OS.set_environment("HOME", saved_home)
	assert_false(home.is_empty())


func test_the_entries_carry_their_size_and_a_modified_time() -> void:
	write_text(_folder + "/five.txt", "12345")

	var entries: Array = _service.list_directory(_folder, FileTypeFilter.all_files()).value

	assert_eq(entries.size(), 1)
	assert_eq((entries[0] as DirectoryEntry).size, 5)
	assert_eq((entries[0] as DirectoryEntry).path, _folder + "/five.txt")
	assert_true((entries[0] as DirectoryEntry).modified_unix > 0)


func test_listing_a_file_instead_of_a_folder_reports_it() -> void:
	# Godot answers "invalid parameter" for this; the service words it.
	write_text(_folder + "/a.txt", "a")

	var result := _service.list_directory(_folder + "/a.txt", FileTypeFilter.all_files())

	assert_false(result.ok)
	assert_eq(FileError.describe(result.error), "This is not a folder")


func test_a_missing_folder_is_described_as_not_found() -> void:
	var result := _service.list_directory(_folder + "/missing", FileTypeFilter.all_files())

	assert_false(result.ok)
	assert_eq(FileError.describe(result.error), "No such file or directory")
