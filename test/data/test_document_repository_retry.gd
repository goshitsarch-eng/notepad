extends TestCase
## Port of document_repository_retry_test.dart. On Windows a virus scanner, a search
## indexer or a backup program can hold a file for a moment right after it is written, and
## moving the finished file over the document then fails with "access denied" or a sharing
## violation. The save waits a little and tries again, instead of reporting a failure that
## a second later would not have happened.
##
## The Dart test injected exceptions with Windows error codes 32, 5 and 33. GDScript's
## replace_file returns a Godot Error, so the "busy" kinds are the ones the repository
## treats as a refusal that may pass.

const BUSY_ERRORS: Array[int] = [
	ERR_FILE_ALREADY_IN_USE, ERR_FILE_NO_PERMISSION, ERR_FILE_CANT_WRITE, ERR_BUSY,
	ERR_FILE_CANT_OPEN,
]

var _folder: String = ""
var _path: String = ""


func before_each() -> void:
	_folder = make_temp_dir()
	_path = _folder + "/a.txt"


func _text_of(path: String) -> String:
	return TextCodec.read_text(read_bytes(path)).text


## A repository whose rename fails [param failures] times with [param error] before it
## really happens. [param attempts] counts the tries.
func _flaky(failures: int, error: int, attempts: Array, delays: Array = [0, 0, 0]) -> DocumentRepository:
	var repository := DocumentRepository.new()
	repository.replace_file = func(temporary: String, target: String) -> int:
		attempts.append(attempts.size() + 1)
		if attempts.size() <= failures:
			return error
		return DirAccess.rename_absolute(temporary, target)
	repository.replace_retry_delays = delays
	return repository


func test_a_save_that_is_blocked_for_a_moment_succeeds_on_a_later_try() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := _flaky(2, ERR_FILE_ALREADY_IN_USE, attempts)

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_true(result.ok)
	assert_eq(attempts.size(), 3)
	assert_eq(_text_of(_path), "changed")
	assert_eq(list_names(_folder), ["a.txt"])


func test_access_denied_and_a_lock_violation_are_retried_as_well() -> void:
	for error in BUSY_ERRORS:
		write_text(_path, "original")
		var attempts := []
		var repository := _flaky(1, error, attempts)

		var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

		assert_true(result.ok, "error %d" % error)
		assert_eq(attempts.size(), 2, "error %d" % error)


func test_a_save_that_stays_blocked_fails_after_the_last_try_and_leaves_the_old_text() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := _flaky(100, ERR_FILE_ALREADY_IN_USE, attempts)

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(attempts.size(), 4, "one try and one per pause")
	assert_eq(_text_of(_path), "original")
	assert_eq(list_names(_folder), ["a.txt"], "the temporary file is removed")


func test_another_kind_of_failure_is_not_retried() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := _flaky(100, ERR_FILE_NOT_FOUND, attempts)

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(attempts.size(), 1)
	assert_eq(_text_of(_path), "original")


func test_the_pauses_are_taken_between_the_tries() -> void:
	write_text(_path, "original")
	var started := Time.get_ticks_msec()
	var attempts := []
	var repository := _flaky(2, ERR_FILE_ALREADY_IN_USE, attempts, [120, 120])

	await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_true(Time.get_ticks_msec() - started >= 220, "waited %d ms" % (Time.get_ticks_msec() - started))


func test_without_pauses_a_blocked_save_is_tried_once() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := _flaky(1, ERR_FILE_ALREADY_IN_USE, attempts, [])

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(attempts.size(), 1)


func test_by_default_only_windows_waits_and_tries_again() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := DocumentRepository.new()
	repository.replace_file = func(temporary: String, target: String) -> int:
		attempts.append(1)
		if attempts.size() == 1:
			return ERR_FILE_ALREADY_IN_USE
		return DirAccess.rename_absolute(temporary, target)

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	if OS.get_name() == "Windows":
		assert_true(result.ok)
		assert_eq(attempts.size(), 2)
	else:
		# The same numbers mean other things elsewhere, so nothing is retried.
		assert_false(result.ok)
		assert_eq(attempts.size(), 1)


func test_on_windows_the_default_pauses_apply_and_the_save_then_succeeds() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := DocumentRepository.new()
	repository.is_windows = true
	repository.replace_file = func(temporary: String, target: String) -> int:
		attempts.append(1)
		if attempts.size() == 1:
			return ERR_FILE_NO_PERMISSION
		return DirAccess.rename_absolute(temporary, target)

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_true(result.ok)
	assert_eq(attempts.size(), 2)
	assert_eq(_text_of(_path), "changed")


func test_on_windows_the_default_pauses_give_up_after_five_tries() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := DocumentRepository.new()
	repository.is_windows = true
	repository.replace_file = func(_temporary: String, _target: String) -> int:
		attempts.append(1)
		return ERR_FILE_ALREADY_IN_USE

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(attempts.size(), 1 + DocumentRepository.WINDOWS_REPLACE_RETRY_DELAYS_MS.size())
	assert_eq(list_names(_folder), ["a.txt"])


func test_off_windows_the_default_does_not_retry_even_when_asked_to_be_windows_false() -> void:
	write_text(_path, "original")
	var attempts := []
	var repository := DocumentRepository.new()
	repository.is_windows = false
	repository.replace_file = func(_temporary: String, _target: String) -> int:
		attempts.append(1)
		return ERR_FILE_ALREADY_IN_USE

	var result: Result = await repository.write(_path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(attempts.size(), 1)
