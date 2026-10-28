class_name PdfPrintingService
extends PrintingService
## Lays the text out as a PDF with the File > Page Setup margins, header and footer, then
## hands it to the system's PDF viewer, where the user prints it. Godot has no printing of
## its own, so the viewer's print dialog stands in for the platform's.

const _FOLDER := "xp_notepad/print"
const _KEEP_SECONDS := 24 * 60 * 60

## How the finished file is opened. Tests replace it to avoid opening a viewer.
var open_file: Callable = Callable(OS, "shell_open")
## Where the PDF is written. Empty is the user's cache folder.
var folder: String = ""
## What the date and time codes show. Empty is the moment of printing.
var moment: Dictionary = {}


func print_document(text: String, document_name: String, setup: PageSetup) -> Result:
	# Margins that leave no room would make the layout meaningless, so the defaults are used
	# for the margins. The header and footer still come from the setup.
	var usable := setup
	if not setup.margin_problem().is_empty():
		var defaults := PageSetup.new()
		usable = setup.copy_with({
			"left_inches": defaults.left_inches,
			"top_inches": defaults.top_inches,
			"right_inches": defaults.right_inches,
			"bottom_inches": defaults.bottom_inches,
		})
	var now: Dictionary = moment if not moment.is_empty() else Time.get_datetime_dict_from_system()
	var bytes: PackedByteArray
	if text.length() > 256 * 1024:
		# Laying out a long document takes seconds, so it runs on a worker thread and the
		# window keeps responding.
		bytes = await _build_in_thread(text, document_name, usable, now)
	else:
		bytes = PdfBuilder.build(text, document_name, usable, now)

	var target_folder := folder if not folder.is_empty() else OS.get_cache_dir().path_join(_FOLDER)
	var made := DirAccess.make_dir_recursive_absolute(target_folder)
	if made != OK and not DirAccess.dir_exists_absolute(target_folder):
		return Result.failure(FileError.from_godot(made, target_folder))
	_remove_old_files(target_folder)
	var path := target_folder.path_join("%s-%d.pdf" % [_safe_name(document_name), Time.get_ticks_usec()])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return Result.failure(FileError.from_godot(FileAccess.get_open_error(), path))
	file.store_buffer(bytes)
	file.close()
	var opened: int = open_file.call(path)
	if opened != OK:
		return Result.failure(FileError.from_godot(opened, path))
	return Result.success(path)


func _build_in_thread(
		text: String, document_name: String, setup: PageSetup, now: Dictionary) -> PackedByteArray:
	var box := [PackedByteArray()]
	var task := WorkerThreadPool.add_task(func() -> void:
		box[0] = PdfBuilder.build(text, document_name, setup, now))
	var tree := Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return box[0]


## A file name made of the document's name, safe on every system.
func _safe_name(document_name: String) -> String:
	var base := document_name.get_basename()
	var safe := ""
	for index in range(base.length()):
		var character := base[index]
		safe += character if character.is_valid_identifier() or character in "-. " else "_"
	return safe if not safe.is_empty() else "Untitled"


## Removes the PDFs of earlier prints, so the folder does not fill up.
func _remove_old_files(target_folder: String) -> void:
	var now := Time.get_unix_time_from_system()
	for file_name in DirAccess.get_files_at(target_folder):
		if not file_name.ends_with(".pdf"):
			continue
		var path := target_folder.path_join(file_name)
		if now - FileAccess.get_modified_time(path) > _KEEP_SECONDS:
			DirAccess.remove_absolute(path)
