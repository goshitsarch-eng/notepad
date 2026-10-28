extends TestCase
## Port of document_repository_test.dart. Saves go through DocumentRepository.write. These
## tests use real files in a temporary folder, because the point is what the file system
## ends up holding.

var _folder: String = ""


func before_each() -> void:
	_folder = make_temp_dir()


func after_each() -> void:
	# A folder or file the test made unreadable has to be opened up before it can be removed.
	if OS.get_name() != "Windows":
		OS.execute("chmod", ["-R", "u+rwx", _folder])


func _text_of(path: String) -> String:
	return TextCodec.read_text(read_bytes(path)).text


func _is_root() -> bool:
	var output: Array = []
	OS.execute("id", ["-u"], output)
	return output.size() > 0 and str(output[0]).strip_edges() == "0"


func _fail_replace(_temporary: String, _path: String) -> int:
	return ERR_FILE_CANT_WRITE


func test_a_new_file_gets_its_text_and_no_temporary_file_is_left_behind() -> void:
	var repository := DocumentRepository.new()
	var path := _folder + "/a.txt"

	var result: Result = await repository.write(path, "Hello\nWorld", FileEncoding.UTF8)

	assert_true(result.ok)
	assert_eq(_text_of(path), "Hello\nWorld")
	assert_eq(list_names(_folder), ["a.txt"])


func test_saving_over_a_file_replaces_its_text_and_leaves_no_temporary_file_behind() -> void:
	var repository := DocumentRepository.new()
	var path := _folder + "/a.txt"
	await repository.write(path, "one", FileEncoding.ANSI)

	await repository.write(path, "two", FileEncoding.ANSI)

	assert_eq(_text_of(path), "two")
	assert_eq(list_names(_folder), ["a.txt"])


func test_a_save_that_fails_at_the_last_step_leaves_the_old_text_and_no_temporary_file() -> void:
	var path := _folder + "/a.txt"
	await DocumentRepository.new().write(path, "original", FileEncoding.ANSI)
	var failing := DocumentRepository.new()
	failing.replace_file = _fail_replace

	var result: Result = await failing.write(path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(_text_of(path), "original")
	assert_eq(list_names(_folder), ["a.txt"])


func test_a_save_that_cannot_write_the_file_fails_and_leaves_the_old_text() -> void:
	if OS.get_name() == "Windows":
		skip("read-only attributes are checked here on POSIX systems only")
		return
	var repository := DocumentRepository.new()
	var path := _folder + "/a.txt"
	await repository.write(path, "original", FileEncoding.ANSI)
	OS.execute("chmod", ["444", path])
	if _is_root() or FileAccess.open(path, FileAccess.READ_WRITE) != null:
		skip("this user can write read-only files, for example as root")
		return

	var result: Result = await repository.write(path, "changed", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_eq(_text_of(path), "original")
	assert_eq(list_names(_folder), ["a.txt"])


func test_a_save_keeps_the_permission_bits_of_the_file_it_replaces() -> void:
	if OS.get_name() == "Windows":
		skip("permission bits are POSIX only")
		return
	var repository := DocumentRepository.new()
	var path := _folder + "/private.txt"
	await repository.write(path, "secret", FileEncoding.ANSI)
	OS.execute("chmod", ["600", path])

	await repository.write(path, "still secret", FileEncoding.ANSI)

	assert_eq(FileAccess.get_unix_permissions(path) & 0x1FF, 0x180)
	assert_eq(_text_of(path), "still secret")


func test_a_save_through_a_symbolic_link_updates_the_target_and_keeps_the_link() -> void:
	if OS.get_name() == "Windows":
		skip("symbolic links need extra privilege on Windows")
		return
	var repository := DocumentRepository.new()
	var target := _folder + "/target.txt"
	var link := _folder + "/link.txt"
	await repository.write(target, "old", FileEncoding.ANSI)
	assert_eq(OS.execute("ln", ["-s", target, link]), 0)

	var result: Result = await repository.write(link, "new", FileEncoding.ANSI)

	assert_true(result.ok)
	assert_true(DirAccess.open(_folder).is_link(link), "the link must survive")
	assert_eq(_text_of(target), "new")
	assert_eq(list_names(_folder), ["link.txt", "target.txt"])


func test_a_folder_that_cannot_take_a_temporary_file_still_saves_the_file_in_place() -> void:
	if OS.get_name() == "Windows":
		skip("folder permissions are POSIX only")
		return
	var repository := DocumentRepository.new()
	var path := _folder + "/a.txt"
	await repository.write(path, "before", FileEncoding.ANSI)
	OS.execute("chmod", ["555", _folder])
	if _is_root():
		# Root can create files in a folder without the write permission, so the
		# temporary file would succeed and the in-place path is never taken.
		skip("root ignores permissions")
		return

	var result: Result = await repository.write(path, "after", FileEncoding.ANSI)

	assert_true(result.ok)
	assert_eq(_text_of(path), "after")


# ---- reading as a chosen encoding ----

func _utf16(text: String) -> PackedByteArray:
	return text.to_utf16_buffer()


func test_a_file_with_nothing_in_it_that_names_its_encoding_is_read_as_asked() -> void:
	var path := _folder + "/jp.txt"
	write_bytes(path, _utf16("日本語のテキストです。\n"))

	var result: Result = await DocumentRepository.new().read(path, FileEncoding.UNICODE)

	assert_true(result.ok)
	var file: TextFile = result.value
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, "日本語のテキストです。\n")


func test_english_utf16_with_no_byte_order_mark_is_found_without_being_asked() -> void:
	var path := _folder + "/en.txt"
	write_bytes(path, _utf16("Hello, world.\nSecond line.\n"))

	var result: Result = await DocumentRepository.new().read(path)

	assert_true(result.ok)
	var file: TextFile = result.value
	assert_eq(file.encoding, FileEncoding.UNICODE)
	assert_eq(file.text, "Hello, world.\nSecond line.\n")


func test_a_large_file_is_read_as_asked_too() -> void:
	# Over 512 KB, so the conversion runs on a worker thread.
	var path := _folder + "/big.txt"
	var text := "日本語のテキストです。\n".repeat(60000)
	write_bytes(path, _utf16(text))
	assert_true(FileAccess.get_size(path) > 512 * 1024)

	var result: Result = await DocumentRepository.new().read(path, FileEncoding.UNICODE)

	assert_true(result.ok)
	assert_true((result.value as TextFile).text == text, "the large file's text differs")


func test_a_large_file_is_written_on_a_worker_thread_and_reads_back() -> void:
	var path := _folder + "/big_write.txt"
	var text := "line of text with é and 日本\n".repeat(30000)
	assert_true(text.length() > 512 * 1024)
	var repository := DocumentRepository.new()

	var written: Result = await repository.write(path, text, FileEncoding.UNICODE)
	var read: Result = await repository.read(path)

	assert_true(written.ok)
	assert_true(read.ok)
	assert_eq((read.value as TextFile).encoding, FileEncoding.UNICODE)
	assert_true((read.value as TextFile).text == text, "the round trip changed the text")
