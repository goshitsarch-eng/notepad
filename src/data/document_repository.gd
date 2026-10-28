class_name DocumentRepository
extends RefCounted
## Source of truth for documents on disk. Reads and writes with FileAccess. Large files are
## converted on a worker thread so that typing and painting stay smooth. Tests replace the
## class with a fake that has the same two methods.

## The largest file Notepad opens by default. The text, and the copies that editing makes of
## it, are held in memory, so a bigger file would exhaust it long before it was usable. The
## limit is enforced while reading, so it also stops a device such as /dev/zero, which
## reports no size, and a file that grows while it is read.
const DEFAULT_MAXIMUM_BYTES := 64 * 1024 * 1024

## About a second in all, which is longer than such a program usually holds a file.
const WINDOWS_REPLACE_RETRY_DELAYS_MS: Array[int] = [50, 150, 300, 500]

const _THREAD_THRESHOLD := 512 * 1024
const _READ_CHUNK := 1024 * 1024

## The limit this repository applies. Tests lower it to avoid writing huge files.
var maximum_bytes: int = DEFAULT_MAXIMUM_BYTES

## Moves a finished temporary file over the document and returns an Error. The default is the
## real rename. Tests replace it to fail the last step of a save.
var replace_file: Callable = _rename_over

## The pauses, in milliseconds, before each new try when moving the finished file over the
## document is refused because something else has the file open for a moment: on Windows a
## virus scanner, a search indexer or a backup program. With none, the first refusal is
## final. When this is null, Windows waits [constant WINDOWS_REPLACE_RETRY_DELAYS_MS] and
## other systems do not wait.
var replace_retry_delays: Variant = null

## Whether the system is Windows. Tests set it to try the retry rule on other systems.
var is_windows: bool = OS.get_name() == "Windows"


## Reads [param path]. With no [param encoding] the file's encoding is detected; with one
## it is read as that, unless it has a byte order mark. Returns a [Result] whose value is a
## [TextFile].
func read(path: String, encoding: int = FileEncoding.DETECT) -> Result:
	var bytes_result := read_bytes(path)
	if not bytes_result.ok:
		return bytes_result
	var bytes: PackedByteArray = bytes_result.value
	if bytes.size() <= _THREAD_THRESHOLD:
		return Result.success(TextCodec.read_text(bytes, encoding))
	var work := func() -> TextFile: return TextCodec.read_text(bytes, encoding)
	var file: TextFile = await _run_in_thread(work)
	return Result.success(file)


## Reads [param path] in chunks and gives up once it passes [member maximum_bytes]. A
## folder, a named pipe or a socket is refused before reading: opening a pipe would wait
## for a writer for ever.
func read_bytes(path: String) -> Result:
	if DirAccess.dir_exists_absolute(path):
		return Result.failure(FileError.make("This is a folder, not a file", path))
	if _is_not_regular_file(path):
		return Result.failure(FileError.make("This is not a regular file", path))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.failure(FileError.from_godot(FileAccess.get_open_error(), path))
	var bytes := PackedByteArray()
	while true:
		var chunk := file.get_buffer(_READ_CHUNK)
		if chunk.is_empty():
			break
		bytes.append_array(chunk)
		if bytes.size() > maximum_bytes:
			return Result.failure(FileError.make(
				"The file is too large. Notepad opens files up to %s" % _describe_size(maximum_bytes),
				path))
	return Result.success(bytes)


## Encodes [param text] and writes it to [param path]. Returns a [Result].
func write(path: String, text: String, encoding: int) -> Result:
	var bytes: PackedByteArray
	if text.length() > _THREAD_THRESHOLD:
		var work := func() -> PackedByteArray: return TextCodec.encode_text(text, encoding)
		bytes = await _run_in_thread(work)
	else:
		bytes = TextCodec.encode_text(text, encoding)
	return await _save(path, bytes)


func _describe_size(bytes: int) -> String:
	const MEGABYTE := 1024 * 1024
	return "%d MB" % (bytes / MEGABYTE) if bytes >= MEGABYTE else "%d bytes" % bytes


## True for a named pipe or a socket, which must not be opened. Windows has neither as a
## file, and Godot cannot tell them apart itself, so the system's own `test` does. A path
## that does not exist is not one, and the open reports it.
func _is_not_regular_file(path: String) -> bool:
	if is_windows:
		return false
	# execute_with_pipe, not OS.execute: in Godot 4.7 OS.execute hands its arguments to a
	# shell inside double quotes, so a `$` or a quote in a file name would be expanded, or
	# run as a command, and the `$1` below would be expanded before this script saw it.
	var started := OS.execute_with_pipe(
		"sh", ["-c", "test -p \"$1\" || test -S \"$1\"", "sh", path], false)
	if started.is_empty():
		return false
	var process_id: int = started["pid"]
	while OS.is_process_running(process_id):
		OS.delay_usec(500)
	return OS.get_process_exit_code(process_id) == 0


## Runs [param work] on a worker thread and waits for it without blocking the window.
func _run_in_thread(work: Callable) -> Variant:
	var box := [null]
	var task := WorkerThreadPool.add_task(func() -> void: box[0] = work.call())
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return box[0]


## Writes [param bytes] to a temporary file beside the document, then moves it over the
## document. An interrupted save therefore leaves either the old file or the new one,
## never a truncated mix, and the temporary file is removed when a step fails.
##
## Symbolic links are followed, so the link itself is kept. On POSIX systems the
## permission bits of the old file are copied to the new one. A document that is
## read-only is still refused, as before. A folder that cannot take a temporary file
## gets the bytes written in place, which is the only case that is not atomic.
func _save(path: String, bytes: PackedByteArray) -> Result:
	var target := PathLinks.resolve(path)
	var exists := FileAccess.file_exists(target)
	if exists:
		# Opening for update changes nothing, but fails on a read-only file.
		var probe := FileAccess.open(target, FileAccess.READ_WRITE)
		if probe == null:
			return Result.failure(FileError.from_godot(FileAccess.get_open_error(), target))
		probe.close()

	var temporary := "%s/.%s.%d.%d.tmp" % [
		target.get_base_dir(), target.get_file(), OS.get_process_id(), Time.get_ticks_usec()]
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		return _write_in_place(target, bytes)
	# The permissions are set while the file is still empty, so a private document never has
	# its text sitting in a file that other users can read.
	if exists and not is_windows:
		var mode_error := FileAccess.set_unix_permissions(temporary, FileAccess.get_unix_permissions(target))
		if mode_error != OK:
			handle.close()
			DirAccess.remove_absolute(temporary)
			return Result.failure(FileError.make("Cannot keep the file permissions", target))
	var stored := handle.store_buffer(bytes)
	handle.flush()
	var write_error := handle.get_error()
	handle.close()
	if not stored or write_error != OK:
		DirAccess.remove_absolute(temporary)
		return Result.failure(FileError.from_godot(
			write_error if write_error != OK else ERR_FILE_CANT_WRITE, target))
	var replaced := await _replace(temporary, target)
	if replaced != OK:
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(temporary)
		return Result.failure(FileError.from_godot(replaced, target))
	return Result.success()


func _write_in_place(target: String, bytes: PackedByteArray) -> Result:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return Result.failure(FileError.from_godot(FileAccess.get_open_error(), target))
	var stored := file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not stored or write_error != OK:
		return Result.failure(FileError.from_godot(
			write_error if write_error != OK else ERR_FILE_CANT_WRITE, target))
	return Result.success()


## Moves the finished file over the document, trying again after a pause while the refusal
## is the kind that passes by itself. Returns an Error.
func _replace(temporary: String, path: String) -> int:
	var delays: Array = []
	if replace_retry_delays != null:
		delays = replace_retry_delays
	elif is_windows:
		delays = WINDOWS_REPLACE_RETRY_DELAYS_MS
	var tries := 0
	var tree := Engine.get_main_loop() as SceneTree
	while true:
		var error: int = replace_file.call(temporary, path)
		if error == OK:
			return OK
		# On Windows a file that another program has open is refused with a general
		# error, so every refusal is treated as one that may pass.
		if tries >= delays.size() or not _is_busy(error):
			return error
		await tree.create_timer(float(delays[tries]) / 1000.0).timeout
		tries += 1
	return FAILED


## A refusal that a file another program has open gives: access denied or in use.
func _is_busy(error: int) -> bool:
	return error == ERR_FILE_NO_PERMISSION or error == ERR_FILE_ALREADY_IN_USE \
		or error == ERR_FILE_CANT_WRITE or error == ERR_BUSY or error == ERR_FILE_CANT_OPEN


static func _rename_over(temporary: String, path: String) -> int:
	return DirAccess.rename_absolute(temporary, path)
