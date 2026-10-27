class_name TestCase
extends RefCounted
## Base class of a test file. Every method whose name starts with `test_` is a test; it may
## `await`. `before_each` and `after_each` run around each one. Assertions do not stop a
## test, they record the failure and return false, so a test can `return` when a later step
## would only fail for the same reason.

## The scene tree the tests run in, for waiting on frames.
var tree: SceneTree
var failures: Array[String] = []
var skipped_reason: String = ""
var _temporary_folders: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ---- Assertions ----

func fail(message: String) -> bool:
	failures.append(message)
	return false


func skip(reason: String) -> void:
	skipped_reason = reason


func assert_true(condition: bool, message: String = "expected true") -> bool:
	if not condition:
		return fail(message)
	return true


func assert_false(condition: bool, message: String = "expected false") -> bool:
	if condition:
		return fail(message)
	return true


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if typeof(actual) != typeof(expected) and not _numbers(actual, expected):
		return fail("%sexpected %s (%s), got %s (%s)" % [
			_prefix(message), _show(expected), type_string(typeof(expected)),
			_show(actual), type_string(typeof(actual))])
	if actual != expected:
		return fail("%sexpected %s, got %s" % [_prefix(message), _show(expected), _show(actual)])
	return true


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> bool:
	if actual == unexpected:
		return fail("%sexpected anything but %s" % [_prefix(message), _show(unexpected)])
	return true


func assert_null(value: Variant, message: String = "") -> bool:
	if value != null:
		return fail("%sexpected null, got %s" % [_prefix(message), _show(value)])
	return true


func assert_not_null(value: Variant, message: String = "expected a value, got null") -> bool:
	if value == null:
		return fail(message)
	return true


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> bool:
	if absf(actual - expected) > tolerance:
		return fail("%sexpected %s within %s, got %s" % [_prefix(message), expected, tolerance, actual])
	return true


func assert_contains(haystack: Variant, needle: Variant, message: String = "") -> bool:
	var found := false
	if haystack is String:
		found = (haystack as String).contains(str(needle))
	elif haystack is Array or haystack is PackedStringArray or haystack is Dictionary:
		found = needle in haystack
	if not found:
		return fail("%sexpected %s to contain %s" % [_prefix(message), _show(haystack), _show(needle)])
	return true


func assert_not_contains(haystack: Variant, needle: Variant, message: String = "") -> bool:
	var found := false
	if haystack is String:
		found = (haystack as String).contains(str(needle))
	elif haystack is Array or haystack is PackedStringArray or haystack is Dictionary:
		found = needle in haystack
	if found:
		return fail("%sexpected %s not to contain %s" % [_prefix(message), _show(haystack), _show(needle)])
	return true


func assert_bytes(actual: PackedByteArray, expected: Array, message: String = "") -> bool:
	var list: Array = Array(actual)
	if list != expected:
		return fail("%sexpected bytes %s, got %s" % [_prefix(message), _hex(expected), _hex(list)])
	return true


## The dialog the view model has open, which must be a [param type] (such as
## DialogRequests.MessageRequest). Fails the test and returns null when it is not.
func modal_of(vm: NotepadViewModel, type: Variant) -> Variant:
	var request: Variant = vm.modal()
	if request == null:
		fail("expected a %s to be open, but no dialog is" % type.get_global_name() if type.has_method("get_global_name") else "expected a dialog to be open, but none is")
		return null
	if not is_instance_of(request, type):
		fail("expected another kind of dialog, got %s" % request)
		return null
	return request


# ---- Waiting ----

func wait_frames(count: int = 1) -> void:
	for _frame in range(count):
		await tree.process_frame


func wait_seconds(seconds: float) -> void:
	await tree.create_timer(seconds).timeout


# ---- Files ----

## A new empty folder that is removed after the test.
func make_temp_dir() -> String:
	var base := OS.get_cache_dir().path_join("xp_notepad_tests")
	DirAccess.make_dir_recursive_absolute(base)
	var folder := "%s/t%d_%d" % [base, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(folder)
	_temporary_folders.append(folder)
	return folder


func write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func write_text(path: String, text: String) -> void:
	write_bytes(path, text.to_utf8_buffer())


func read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func read_text(path: String) -> String:
	return read_bytes(path).get_string_from_utf8()


## The names in [param folder], sorted.
func list_names(folder: String) -> Array:
	var names: Array = []
	var access := DirAccess.open(folder)
	if access == null:
		return names
	access.include_hidden = true
	for name in access.get_files():
		names.append(name)
	for name in access.get_directories():
		names.append(name)
	names.sort()
	return names


func cleanup_files() -> void:
	for folder in _temporary_folders:
		_remove_tree(folder)
	_temporary_folders.clear()


func _remove_tree(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	access.include_hidden = true
	for name in access.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in access.get_directories():
		_remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)


# ---- Helpers ----

func _numbers(a: Variant, b: Variant) -> bool:
	return (a is int or a is float) and (b is int or b is float)


func _prefix(message: String) -> String:
	return "" if message.is_empty() else message + ": "


func _hex(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append("%02X" % value)
	return "[" + " ".join(parts) + "]"


func _show(value: Variant) -> String:
	if value is String:
		var shown := (value as String).c_escape()
		return "\"%s\"" % (shown.substr(0, 120) + "..." if shown.length() > 120 else shown)
	return var_to_str(value) if value is Object == false else str(value)
