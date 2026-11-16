class_name CADTrace
extends RefCounted
## Opt-in bounded diagnostics. Monotonic wall timestamps are separate from the
## interaction's active-time clock; events contain scalar data, never scene nodes.

var enabled := false
var capacity := 256:
	set(value):
		capacity = clampi(value, 1, 1024)
		_trim()
var time_source: Callable
var last_error := ""
var dropped := 0
var _run := 0
var _base := 0.0
var _last := 0.0
var _index := 0
var _events: Array[Dictionary] = []

func reset(run: int) -> void:
	_run = run
	_base = _now()
	_last = 0.0
	_index = 0
	dropped = 0
	last_error = ""
	_events.clear()

func record(kind: StringName, fields: Dictionary = {}) -> bool:
	if not enabled:
		return false
	last_error = ""
	if kind == &"" or String(kind).length() > 64 or fields.size() > 32:
		last_error = "Trace event needs a short ID and at most 32 scalar fields."
		return false
	var values := {}
	for key in fields:
		var value: Variant = fields[key]
		if (key is not String and key is not StringName) or String(key).length() > 64 \
				or (value != null and value is not String and value is not StringName and value is not bool and value is not int and value is not float) \
				or (value is float and not is_finite(value)):
			last_error = "Trace fields must have short text keys and finite scalar values."
			return false
		values[String(key)] = String(value).left(256) if value is String or value is StringName else value
	_last = maxf(_last, maxf(0.0, _now() - _base))
	_index += 1
	_events.append({"event": String(kind), "index": _index, "seconds": _last, "data": values})
	_trim()
	return true

func snapshot() -> Dictionary:
	return {"schema": 1, "run_id": _run, "dropped": dropped, "events": _events.duplicate(true)}

func write_json(path: String) -> bool:
	var error := save_snapshot(snapshot(), path)
	last_error = "" if error == OK else error_string(error)
	return error == OK

static func save_snapshot(data: Dictionary, path: String) -> Error:
	if not path.begins_with("user://"):
		return ERR_INVALID_PARAMETER
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _trim() -> void:
	while _events.size() > capacity:
		_events.pop_front()
		dropped += 1

func _now() -> float:
	var value := float(time_source.call()) if time_source.is_valid() else Time.get_ticks_usec() / 1000000.0
	return value if is_finite(value) else _base + _last
