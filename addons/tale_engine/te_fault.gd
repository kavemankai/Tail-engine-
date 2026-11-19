class_name TEFault
extends RefCounted
## One place every runtime fault is reported, so a game can log or upload them
## and tests can observe them. Without a handler, faults go to push_error.

## Called with the message instead of push_error when valid.
static var handler := Callable()
## Also called with every fault, handled or not: crash reports, telemetry.
static var listeners: Array[Callable] = []

static func report(message: String) -> void:
	for listener in listeners:
		if listener.is_valid():
			listener.call(message)
	if handler.is_valid():
		handler.call(message)
	else:
		push_error(message)
