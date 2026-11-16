class_name TESave
extends RefCounted
## Checkpoint saves as JSON in user://saves. A save holds the episode path and
## the list of checkpoints reached, each with its step id and a Story dump.

const VERSION := 1

static func path(slot: int) -> String:
	return "user://saves/slot_%d.json" % slot

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))

static func write(slot: int, episode_path: String, checkpoints: Array) -> bool:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file := FileAccess.open(path(slot), FileAccess.WRITE)
	if file == null:
		return false
	var data := {"version": VERSION, "episode": episode_path, "checkpoints": checkpoints}
	file.store_string(JSON.stringify(JSON.from_native(data), "\t"))
	return true

## The saved dictionary, or empty if there is no usable save.
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	if parsed == null:
		return {}
	var data: Variant = JSON.to_native(parsed)
	if data is not Dictionary or data.get("version") != VERSION:
		return {}
	return data

static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))
