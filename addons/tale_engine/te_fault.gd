class_name TEFault
extends RefCounted
## One place every runtime fault is reported, so a game can log or upload them
## and tests can observe them. Without a handler, faults go to push_error.

## Called with the message instead of push_error when valid.
static var handler := Callable()

static func report(message: String) -> void:
	if handler.is_valid():
		handler.call(message)
	else:
		push_error(message)
