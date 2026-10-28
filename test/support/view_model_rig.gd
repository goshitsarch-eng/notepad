class_name ViewModelRig
extends RefCounted
## A view model built on fakes, with the fakes at hand, as the tests of the window need it.

var documents := FakeDocumentRepository.new()
var settings := FakeSettingsRepository.new()
var file_system := FakeFileSystemService.new()
var printing := FakePrintingService.new()
var window := FakeWindowService.new()
var vm: NotepadViewModel


## [param initial] is the settings the window starts with. The clock is fixed at 3:05 PM on
## 10/7/2026.
func _init(initial: NotepadSettings = null, start_it: bool = true) -> void:
	var dependencies := AppDependencies.new()
	dependencies.documents = documents
	dependencies.settings = settings
	dependencies.file_system = file_system
	dependencies.printing = printing
	dependencies.window = window
	var fixed_clock := func() -> Dictionary:
		return {"year": 2026, "month": 10, "day": 7, "hour": 15, "minute": 5, "second": 0}
	vm = NotepadViewModel.new(dependencies, initial if initial != null else NotepadSettings.new(), fixed_clock)
	if start_it:
		vm.start()


func dispose() -> void:
	vm.dispose()


## Replaces the document text as if it were typed.
func type_text(value: String) -> void:
	vm.text.select_all()
	vm.text.replace_selection(value)


## The text of the document.
func text() -> String:
	return vm.text.get_text()


## Selects the characters from [param start] to [param end], counted through the whole text.
func select(start: int, end: int) -> void:
	vm.text.select_offsets(vm.text.get_text(), start, end)


## The open dialog, which must be of [param kind] (a DialogRequests class).
func modal() -> Variant:
	return vm.modal()
