class_name PrintingService
extends RefCounted
## Sends a document to the platform's printing. Tests replace it with a fake.


## Returns a [Result].
func print_document(_text: String, _document_name: String, _setup: PageSetup) -> Result:
	return Result.success()
