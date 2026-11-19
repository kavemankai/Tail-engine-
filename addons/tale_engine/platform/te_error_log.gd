class_name TEErrorLog
extends Logger
## Keeps the most recent engine errors and warnings in memory, so a crash
## report or a fault can include them. Godot calls this from any thread.

const KEEP := 200

var _lines: PackedStringArray = []
var _mutex := Mutex.new()

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind: String = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)]
	var text := rationale if rationale != "" else code
	_add("%s %s: %s (%s:%d in %s)" % [Time.get_datetime_string_from_system(), kind, text, file, line, function])

func _log_message(message: String, error: bool) -> void:
	if error:
		_add("%s %s" % [Time.get_datetime_string_from_system(), message.strip_edges()])

func _add(text: String) -> void:
	_mutex.lock()
	_lines.append(text)
	if _lines.size() > KEEP:
		_lines = _lines.slice(_lines.size() - KEEP)
	_mutex.unlock()

func lines() -> PackedStringArray:
	_mutex.lock()
	var copy := _lines.duplicate()
	_mutex.unlock()
	return copy

func clear() -> void:
	_mutex.lock()
	_lines.clear()
	_mutex.unlock()
