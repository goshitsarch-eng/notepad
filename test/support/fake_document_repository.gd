class_name FakeDocumentRepository
extends DocumentRepository
## In-memory documents keyed by path. A read or a write can be held until the test lets it go,
## to try what happens while one is still going.

## The bytes of each file.
var files: Dictionary = {}
## Each write, as {"path", "text", "encoding"}.
var writes: Array[Dictionary] = []
## Errors to fail a read of a path with, instead of looking in [member files].
var read_failures: Dictionary = {}
## When set, every write fails with this error and nothing is stored.
var write_failure: Variant = null
## The encoding each read was asked for, or FileEncoding.DETECT where it was left to detection.
var read_encodings: Array[int] = []
## While set, a read does not finish until [method release_reads] is called.
var hold_reads := false
## While set, a write does not finish until [method release_writes] is called.
var hold_writes := false

signal _reads_released
signal _writes_released


func read(path: String, encoding: int = FileEncoding.DETECT) -> Result:
	read_encodings.append(encoding)
	if hold_reads:
		await _reads_released
	if read_failures.has(path):
		return Result.failure(read_failures[path])
	if not files.has(path):
		return Result.failure(FileError.make("missing %s" % path, path))
	return Result.success(TextCodec.read_text(files[path], encoding))


func write(path: String, text: String, encoding: int) -> Result:
	if hold_writes:
		await _writes_released
	if write_failure != null:
		return Result.failure(write_failure)
	writes.append({"path": path, "text": text, "encoding": encoding})
	files[path] = TextCodec.encode_text(text, encoding)
	return Result.success()


func release_reads() -> void:
	hold_reads = false
	_reads_released.emit()


func release_writes() -> void:
	hold_writes = false
	_writes_released.emit()
