class_name FileError
extends RefCounted
## A failed file operation. [member os_message] is the system's own wording when it gave
## one; [member message] is the app's wording for the cases the system does not report.

enum Kind { OTHER, NOT_FOUND }

var kind: int = Kind.OTHER
var message: String = ""
var os_message: String = ""
var path: String = ""
var code: int = OK


static func make(
		error_message: String, error_path: String = "", error_kind: int = Kind.OTHER,
		error_os_message: String = "") -> FileError:
	var error := FileError.new()
	error.message = error_message
	error.path = error_path
	error.kind = error_kind
	error.os_message = error_os_message
	return error


## Builds the error for a Godot [enum Error] code, such as the one FileAccess.get_open_error
## returns, with the wording an operating system gives for it.
static func from_godot(error_code: int, error_path: String = "") -> FileError:
	var error := FileError.new()
	error.code = error_code
	error.path = error_path
	error.os_message = _wording(error_code)
	error.message = error.os_message
	if error_code == ERR_FILE_NOT_FOUND or error_code == ERR_DOES_NOT_EXIST:
		error.kind = Kind.NOT_FOUND
	return error


static func _wording(error_code: int) -> String:
	match error_code:
		ERR_FILE_NOT_FOUND, ERR_DOES_NOT_EXIST:
			return "No such file or directory"
		ERR_FILE_BAD_DRIVE:
			return "The drive cannot be found"
		ERR_FILE_BAD_PATH, ERR_INVALID_PARAMETER:
			return "The path is not valid"
		ERR_FILE_NO_PERMISSION, ERR_UNAUTHORIZED:
			return "Permission denied"
		ERR_FILE_ALREADY_IN_USE, ERR_BUSY:
			return "The file is in use by another program"
		ERR_FILE_CANT_OPEN:
			return "The file cannot be opened"
		ERR_FILE_CANT_WRITE:
			return "The file cannot be written"
		ERR_FILE_CANT_READ:
			return "The file cannot be read"
		ERR_OUT_OF_MEMORY:
			return "Not enough memory"
		ERR_FILE_EOF:
			return "Unexpected end of file"
		_:
			return error_string(error_code)


## A short reason for a failed file operation, such as "Permission denied", for the
## message boxes. Uses the system's own wording when it gave one. Returns an empty string
## when the error carries no usable reason, so the caller can leave the line out.
static func describe(error: Variant) -> String:
	if not (error is FileError):
		return ""
	var system := (error as FileError).os_message.strip_edges()
	var reason := system if not system.is_empty() else (error as FileError).message.strip_edges()
	if reason.is_empty():
		return ""
	# Windows messages already end with a full stop. Keep every reason without one.
	return reason.substr(0, reason.length() - 1) if reason.ends_with(".") else reason
