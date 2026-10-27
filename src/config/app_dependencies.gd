class_name AppDependencies
extends RefCounted
## The repositories and services the app is built from. Tests build the same graph with
## fakes, so nothing in the view layer reaches for a global object.

var documents: DocumentRepository
var settings: SettingsRepository
var file_system: FileSystemService
var printing: PrintingService
var window: WindowService


static func standard(main_window: Window) -> AppDependencies:
	var dependencies := AppDependencies.new()
	dependencies.documents = DocumentRepository.new()
	dependencies.settings = JsonFileSettingsRepository.standard()
	dependencies.file_system = FileSystemService.new()
	dependencies.printing = PdfPrintingService.new()
	dependencies.window = GodotWindowService.new(main_window)
	return dependencies
