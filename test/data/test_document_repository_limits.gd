extends TestCase
## Port of document_repository_limits_test.dart. Reading must stay bounded and refuse what
## is not a plain file, and the reasons given for a failure must reach the person who has
## to read them. Also guards the Godot-specific decisions around the codec.

var _folder: String = ""


func before_each() -> void:
	_folder = make_temp_dir()


func _failure_of(result: Result) -> FileError:
	assert_false(result.ok, "expected a failure")
	assert_true(result.error is FileError, "the error is a FileError")
	return result.error as FileError


func test_a_file_over_the_limit_is_refused_with_a_reason_that_names_the_limit() -> void:
	var path := _folder + "/big.txt"
	write_bytes(path, ("a".repeat(2048)).to_ascii_buffer())
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 1024

	var error := _failure_of(await repository.read(path))

	assert_contains(FileError.describe(error), "too large")
	assert_contains(FileError.describe(error), "1024 bytes")


func test_a_file_that_spans_many_read_chunks_comes_back_byte_for_byte() -> void:
	# Every line is different, so a reused or overwritten chunk buffer would show.
	var lines := PackedStringArray()
	for i in range(80000):
		lines.append("line number %d of the file" % i)
	var text := "\n".join(lines)
	var path := _folder + "/chunks.txt"
	write_text(path, text)
	# The repository reads in chunks of 1 MB.
	assert_true(FileAccess.get_size(path) > 2 * 1024 * 1024)

	var result: Result = await DocumentRepository.new().read(path)

	assert_true(result.ok)
	assert_true((result.value as TextFile).text == text, "the text differs")


func test_a_file_exactly_at_the_limit_still_opens() -> void:
	var path := _folder + "/edge.txt"
	write_bytes(path, ("a".repeat(1024)).to_ascii_buffer())
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 1024

	var result: Result = await repository.read(path)

	assert_true(result.ok)
	assert_eq((result.value as TextFile).text, "a".repeat(1024))


func test_a_file_one_byte_over_the_limit_is_refused() -> void:
	var path := _folder + "/edge.txt"
	write_bytes(path, ("a".repeat(1025)).to_ascii_buffer())
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 1024

	var result: Result = await repository.read(path)

	assert_false(result.ok)


func test_dev_zero_is_refused_instead_of_filling_memory() -> void:
	if OS.get_name() == "Windows":
		skip("POSIX devices only")
		return
	# Differs from Dart: there /dev/zero opened and was stopped at the limit. Godot 4.7
	# refuses to open a character device at all ("Can't open file"), so it fails before the
	# limit is reached. Either way it must fail and must not read for ever.
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 4096

	var result: Result = await repository.read("/dev/zero")

	assert_false(result.ok)


func test_a_file_that_reports_no_size_is_stopped_at_the_limit() -> void:
	# Stands in for the Dart /dev/zero test: /proc/cpuinfo reports a length of zero, so
	# only the check made while reading can stop it.
	if not FileAccess.file_exists("/proc/cpuinfo"):
		skip("needs /proc/cpuinfo")
		return
	var probe := FileAccess.open("/proc/cpuinfo", FileAccess.READ)
	if probe == null or probe.get_length() != 0:
		skip("this system reports a size for /proc/cpuinfo")
		return
	probe.close()
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 100

	var error := _failure_of(await repository.read("/proc/cpuinfo"))

	assert_contains(FileError.describe(error), "too large")


func test_a_folder_is_refused_with_a_reason_instead_of_an_operating_system_error() -> void:
	var error := _failure_of(await DocumentRepository.new().read(_folder))

	assert_eq(FileError.describe(error), "This is a folder, not a file")


func test_a_named_pipe_is_refused_so_the_open_cannot_wait_for_ever() -> void:
	if OS.get_name() == "Windows":
		skip("named pipes are POSIX only")
		return
	var pipe := _folder + "/pipe"
	assert_eq(OS.execute("mkfifo", [pipe]), 0)
	# Dart guarded this with a 5 second timeout. GDScript cannot cancel a read that waits
	# for a writer, so a regression here would hang the run: the refusal has to come first.

	var error := _failure_of(await DocumentRepository.new().read(pipe))

	assert_eq(FileError.describe(error), "This is not a regular file")


func test_a_missing_file_fails_as_not_found_which_the_view_model_words_as_xp_does() -> void:
	var error := _failure_of(await DocumentRepository.new().read(_folder + "/nothing.txt"))

	assert_eq(error.kind, FileError.Kind.NOT_FOUND)


func test_a_save_that_fails_comes_back_as_a_failure_with_a_readable_reason() -> void:
	# The folder does not exist, so neither a temporary file nor the file can be made.
	var result: Result = await DocumentRepository.new().write(
		_folder + "/no/such/folder/a.txt", "text", FileEncoding.ANSI)

	assert_false(result.ok)
	assert_false(FileError.describe(result.error).is_empty())


func test_describe_file_error_prefers_the_system_wording_and_trims_its_full_stop() -> void:
	assert_eq(
		FileError.describe(FileError.make("Cannot open file", "/x", FileError.Kind.OTHER, "Access is denied.")),
		"Access is denied")
	assert_eq(
		FileError.describe(FileError.make("The file is too large", "/x")),
		"The file is too large")
	assert_eq(FileError.describe(RefCounted.new()), "")
	assert_eq(FileError.describe(null), "")


# ---- Godot-specific decisions ----

func test_a_file_with_nul_bytes_opens_with_spaces_in_their_place() -> void:
	var path := _folder + "/nul.txt"
	write_bytes(path, PackedByteArray([0x61, 0x00, 0x62, 0x00, 0x63]))

	var result: Result = await DocumentRepository.new().read(path, FileEncoding.ANSI)

	assert_true(result.ok)
	assert_eq((result.value as TextFile).text, "a b c")


func test_a_file_with_a_lone_surrogate_opens_with_u_fffd_in_its_place() -> void:
	var path := _folder + "/lone.txt"
	write_bytes(path, PackedByteArray([0xFF, 0xFE, 0x61, 0x00, 0x00, 0xD8, 0x62, 0x00]))

	var result: Result = await DocumentRepository.new().read(path)

	assert_true(result.ok)
	assert_eq((result.value as TextFile).text, "a�b")


func test_a_large_file_round_trips_up_to_the_limit() -> void:
	# The default limit is 64 MB; a smaller one stands in so the test stays quick. The
	# file is just under it and must come back intact, and one byte more must be refused.
	var repository := DocumentRepository.new()
	repository.maximum_bytes = 3 * 1024 * 1024
	var line := "0123456789 abcdefghij é 日本語 line\n"
	var text := line.repeat(60000)
	var path := _folder + "/large.txt"
	var written: Result = await repository.write(path, text, FileEncoding.UTF8)
	assert_true(written.ok)
	var size := FileAccess.get_size(path)
	assert_true(size > 2 * 1024 * 1024 and size <= repository.maximum_bytes, "size %d" % size)

	var result: Result = await repository.read(path)

	assert_true(result.ok)
	assert_eq((result.value as TextFile).encoding, FileEncoding.UTF8)
	assert_true((result.value as TextFile).text == text, "the large file changed on the round trip")

	repository.maximum_bytes = size - 1
	assert_false((await repository.read(path)).ok, "one byte over the limit is refused")


func test_the_default_limit_is_64_megabytes() -> void:
	assert_eq(DocumentRepository.new().maximum_bytes, 64 * 1024 * 1024)


func test_a_file_name_with_shell_characters_opens_and_runs_nothing() -> void:
	# Godot 4.7's OS.execute passes arguments through a shell. The check for pipes must not,
	# or this name would run a command and the quotes in it would break the check.
	if OS.get_name() == "Windows":
		skip("these characters are not allowed in Windows file names")
		return
	var marker := _folder + "/marker"
	var name := "a $(touch %s) `touch %s` \"q\" 'single' $HOME.txt" % [marker, marker]
	var path := _folder.path_join(name)
	write_text(path, "content")
	assert_true(FileAccess.file_exists(path), "the test file exists")

	var result: Result = await DocumentRepository.new().read(path)

	assert_true(result.ok)
	assert_eq((result.value as TextFile).text, "content")
	assert_false(FileAccess.file_exists(marker), "no command was run")
