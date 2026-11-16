class_name TESave
extends RefCounted
## Checkpoint saves as JSON in user://saves. A save holds the episode path and
## the list of checkpoints reached, each with its step id and a Story dump.

const VERSION := 1
static var last_error := ""

static func path(slot: int) -> String:
	return "user://saves/slot_%d.json" % slot

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))

static func write(slot: int, episode_path: String, checkpoints: Array) -> bool:
	last_error = ""
	var data := {"version": VERSION, "episode": episode_path, "checkpoints": checkpoints}
	if slot < 0 or not _usable(data):
		last_error = "Invalid save data."
		return false
	var error := DirAccess.make_dir_recursive_absolute("user://saves")
	if error != OK:
		last_error = "Cannot create save directory: %s" % error_string(error)
		return false
	var temporary := path(slot) + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open temporary save: %s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(JSON.from_native(data), "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path(slot))
	if error != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "Cannot replace save: %s" % error_string(error)
		return false
	return true

## The saved dictionary, or empty if there is no usable save.
static func read(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path(slot))) != OK:
		return {}
	var data: Variant = JSON.to_native(json.data)
	if not _usable(data):
		return {}
	return data

## Validate before callers index fields or replace an active session.
static func _usable(data: Variant) -> bool:
	if data is not Dictionary or data.get("version") != VERSION:
		return false
	var episode_path: Variant = data.get("episode")
	var checkpoints: Variant = data.get("checkpoints")
	if episode_path is not String or not episode_path.begins_with("res://") \
			or checkpoints is not Array or checkpoints.is_empty() or not ResourceLoader.exists(episode_path):
		return false
	var episode := load(episode_path) as TEEpisode
	if episode == null or episode.manifest == null or episode.cast == null:
		return false
	for checkpoint: Variant in checkpoints:
		if checkpoint is not Dictionary or not _text(checkpoint.get("step")) \
				or checkpoint.get("title") is not String or not _story(checkpoint.get("story")):
			return false
		var step := episode.find(StringName(checkpoint["step"]))
		if step == null or not step.checkpoint:
			return false
		for key: Variant in checkpoint["story"]["vars"]:
			if not episode.manifest.has_variable(StringName(key)):
				return false
			var initial: Variant = episode.manifest.variables[key]
			if initial != null and typeof(checkpoint["story"]["vars"][key]) != typeof(initial):
				return false
		for key: Variant in checkpoint["story"]["choices"]:
			if not episode.manifest.has_option(StringName(key), StringName(checkpoint["story"]["choices"][key])):
				return false
	return true

static func _text(value: Variant) -> bool:
	return value is String or value is StringName

static func _story(story: Variant) -> bool:
	if story is not Dictionary:
		return false
	for field: String in ["vars", "choices", "outcomes", "results", "seen"]:
		if story.get(field) is not Dictionary:
			return false
		for key: Variant in story[field]:
			if not _text(key):
				return false
	for field: String in ["choices", "outcomes"]:
		for value: Variant in story[field].values():
			if not _text(value):
				return false
	for result: Variant in story["results"].values():
		if result is not Dictionary:
			return false
		for key: Variant in result:
			if not _text(key) or not _text(result[key]):
				return false
	for value: Variant in story["seen"].values():
		if value is not bool:
			return false
	return true

static func erase(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))
