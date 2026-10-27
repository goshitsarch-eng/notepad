class_name FakePrintingService
extends PrintingService
## Remembers what was printed.

## The document name of each print.
var printed: Array[String] = []
## The text of each print.
var printed_text: Array[String] = []
## The page setup of each print.
var setups: Array[PageSetup] = []
## When set, printing fails with this error.
var failure: Variant = null


func print_document(text: String, document_name: String, setup: PageSetup) -> Result:
	printed.append(document_name)
	printed_text.append(text)
	setups.append(setup)
	if failure != null:
		return Result.failure(failure)
	return Result.success()
