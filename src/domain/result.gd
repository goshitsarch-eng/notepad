class_name Result
extends RefCounted
## The outcome of an operation that can fail. Callers handle both cases explicitly.

var ok: bool = true
## The value of a successful outcome.
var value: Variant = null
## What went wrong, for a failed outcome: usually a [FileError].
var error: Variant = null


static func success(result_value: Variant = null) -> Result:
	var result := Result.new()
	result.ok = true
	result.value = result_value
	return result


static func failure(result_error: Variant) -> Result:
	var result := Result.new()
	result.ok = false
	result.error = result_error
	return result
