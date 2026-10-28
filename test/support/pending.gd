class_name Pending
extends RefCounted
## A command that was started and may be waiting for a dialog to be answered, as the tests
## drive the view model: start it, answer what it asks, then collect the result.
##   var saving := Pending.start(rig.vm.save)
##   rig.vm.modal().complete(...)
##   assert_true(await saving.wait())

signal done(value: Variant)

var finished := false
var result: Variant = null


## Starts [param command], a view model method, and returns at once. It runs on as far as it
## can, and again each time a dialog it waits for is answered.
static func start(command: Callable) -> Pending:
	var pending := Pending.new()
	pending._run(command)
	return pending


func _run(command: Callable) -> void:
	result = await command.call()
	finished = true
	done.emit(result)


## The command's result, waiting for it to finish if it has not.
func wait() -> Variant:
	if finished:
		return result
	await done
	return result
