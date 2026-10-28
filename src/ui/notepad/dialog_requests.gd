class_name DialogRequests
extends RefCounted
## The dialogs the window can ask for. A request is shown by the screen and answered with
## [method Request.complete]; the view model waits for the answer with [method Request.result].

enum MessageIcon { INFORMATION, WARNING, ERROR }
enum MessageChoice { YES, NO, CANCEL, OK }
enum FileDialogMode { OPEN, SAVE }


## A dialog that blocks the window until it is answered.
class Request extends RefCounted:
	signal completed(value: Variant)

	var is_done := false
	var answer: Variant = null

	## Answers the dialog. A null [param value] means the dialog was cancelled. Only the
	## first answer counts.
	func complete(value: Variant = null) -> void:
		if is_done:
			return
		is_done = true
		answer = value
		completed.emit(value)

	## Waits for the answer.
	func result() -> Variant:
		if is_done:
			return answer
		await completed
		return answer


class MessageRequest extends Request:
	var title: String
	var text: String
	var icon: int
	var choices: Array[int]

	func _init(message_title: String, message_text: String, message_icon: int, message_choices: Array[int]) -> void:
		title = message_title
		text = message_text
		icon = message_icon
		choices = message_choices


class GoToRequest extends Request:
	var current_line: int

	func _init(line: int) -> void:
		current_line = line


class FontRequest extends Request:
	var initial: EditorFont

	func _init(font: EditorFont) -> void:
		initial = font


class PageSetupRequest extends Request:
	var initial: PageSetup

	func _init(setup: PageSetup) -> void:
		initial = setup


class AboutRequest extends Request:
	pass


## Help > Help Topics. Shows the keyboard shortcuts the app responds to.
class HelpRequest extends Request:
	pass


## The file a user picked in the Open or Save As dialog, and the encoding to save with.
class FileChoice extends RefCounted:
	var path: String
	## The encoding Save As writes the file in.
	var encoding: int
	## The encoding the Open dialog was told to read the file as, or FileEncoding.DETECT.
	var open_as: int

	func _init(choice_path: String = "", choice_encoding: int = FileEncoding.ANSI,
			choice_open_as: int = FileEncoding.DETECT) -> void:
		path = choice_path
		encoding = choice_encoding
		open_as = choice_open_as


class FileRequest extends Request:
	var mode: int
	var start_directory: String
	var encoding: int
	var suggested_name: String

	func _init(file_mode: int, directory: String, file_encoding: int, name: String = "") -> void:
		mode = file_mode
		start_directory = directory
		encoding = file_encoding
		suggested_name = name


## The modeless Find or Replace dialog. It stays open while the document is edited.
class FindState extends RefCounted:
	var replace: bool

	func _init(for_replace: bool = false) -> void:
		replace = for_replace
