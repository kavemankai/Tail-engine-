class_name TESave
extends RefCounted
## Checkpoint saves as JSON in user://saves. A save holds the episode path and
## the list of checkpoints reached, each with its step id and a Story dump.
##
## Reading is tolerant of content changes: a save made before an episode was
## patched is repaired (renamed or removed steps and variables) instead of
## being thrown away. Only a structurally damaged file is rejected, and then
## the previous good write (slot_N.json.bak) is used.

const VERSION := 2

enum Status {
	NONE,        ## No save in the slot.
	OK,          ## Read as written.
	RECOVERED,   ## Read, but repaired for changed content or taken from the backup.
	UNREADABLE,  ## A file exists and neither it nor its backup could be used.
}

static var last_error := ""
## Result of the most recent read().
static var last_status := Status.NONE
## What the most recent read() or write() had to change, one line each.
static var last_notes := PackedStringArray()

static func path(slot: int) -> String:
	return "user://saves/slot_%d.json" % slot

static func backup_path(slot: int) -> String:
	return path(slot) + ".bak"

static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))

## `season_info` is optional: { "path": season resource path, "index": episode index }.
## `meta` is free-form details for the slot list; saved_at and the titles are filled in.
static func write(slot: int, episode_path: String, checkpoints: Array, season_info: Dictionary = {}, meta: Dictionary = {}) -> bool:
	last_error = ""
	last_notes = PackedStringArray()
	var data := {"version": VERSION, "episode": episode_path, "checkpoints": checkpoints.duplicate(true)}
	if not season_info.is_empty():
		data["season"] = season_info
	if slot < 0 or not _well_formed(data):
		last_error = "Invalid save data."
		return false
	# Never refuse to save over a stray value: drop it and keep the rest.
	_repair(data)
	for note in last_notes:
		push_warning("Save: " + note)
	var episode := load(episode_path) as TEEpisode
	var details := meta.duplicate(true)
	details["saved_at"] = int(Time.get_unix_time_from_system())
	details["episode_title"] = episode.title
	details["checkpoint_title"] = data["checkpoints"].back()["title"]
	data["meta"] = details
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
		# Keep the previous good save. Losing the backup is not a reason to fail.
		if exists(slot) and not _parse(path(slot)).is_empty():
			DirAccess.copy_absolute(path(slot), backup_path(slot))
		error = DirAccess.rename_absolute(temporary, path(slot))
	if error != OK:
		DirAccess.remove_absolute(temporary)
		last_error = "Cannot replace save: %s" % error_string(error)
		return false
	return true

## The saved dictionary, or empty if there is no usable save. Check last_status
## to tell "nothing saved" from "a save exists but could not be read".
static func read(slot: int) -> Dictionary:
	last_error = ""
	last_notes = PackedStringArray()
	last_status = Status.NONE
	var candidates := [path(slot), backup_path(slot)]
	var found := false
	for index in candidates.size():
		if not FileAccess.file_exists(candidates[index]):
			continue
		found = true
		last_notes = PackedStringArray()
		var data := _parse(candidates[index])
		if data.is_empty() or not _well_formed(data):
			continue
		_repair(data)
		if index > 0:
			last_notes.append("The newest save was damaged; an earlier one was used.")
		last_status = Status.OK if last_notes.is_empty() else Status.RECOVERED
		return data
	if found:
		last_status = Status.UNREADABLE
		last_error = "The save in this slot is damaged or was made by a newer version."
		last_notes = PackedStringArray()
	return {}

## Slot summary for menus, without the checkpoint data:
## { status, episode_title, checkpoint_title, saved_at, playtime, checkpoints }.
static func info(slot: int) -> Dictionary:
	var data := read(slot)
	var summary := {"status": last_status}
	if data.is_empty():
		return summary
	var meta: Dictionary = data.get("meta", {})
	summary["episode_title"] = String(meta.get("episode_title", ""))
	summary["checkpoint_title"] = String(meta.get("checkpoint_title", data["checkpoints"].back()["title"]))
	summary["saved_at"] = int(meta.get("saved_at", 0))
	summary["playtime"] = float(meta.get("playtime", 0.0))
	summary["checkpoints"] = data["checkpoints"].size()
	return summary

static func erase(slot: int) -> void:
	for file: String in [path(slot), backup_path(slot)]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)

## Parse a file and bring it to the current version. Empty when unreadable.
static func _parse(file: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file)) != OK:
		return {}
	var data: Variant = JSON.to_native(json.data)
	if data is not Dictionary:
		return {}
	return _migrate(data)

## Step a save forward one version at a time. A save from a newer build is
## left alone (empty result) rather than guessed at.
static func _migrate(data: Dictionary) -> Dictionary:
	var version: Variant = data.get("version")
	if version is not int or version < 1 or version > VERSION:
		return {}
	if version == 1:
		# Version 2 added the "meta" block; everything else is unchanged.
		data["meta"] = {}
		data["version"] = 2
	return data

## Structure only: the right fields with the right types, and an episode that
## still loads. Content that no longer matches the episode is _repair's job.
static func _well_formed(data: Dictionary) -> bool:
	if data.get("version") != VERSION:
		return false
	var episode_path: Variant = data.get("episode")
	var checkpoints: Variant = data.get("checkpoints")
	if episode_path is not String or not episode_path.begins_with("res://") \
			or checkpoints is not Array or checkpoints.is_empty() or not ResourceLoader.exists(episode_path):
		return false
	if data.has("season") and not _season(data["season"]):
		return false
	if data.has("meta") and data["meta"] is not Dictionary:
		return false
	var episode := load(episode_path) as TEEpisode
	if episode == null or episode.manifest == null or episode.cast == null:
		return false
	for checkpoint: Variant in checkpoints:
		if checkpoint is not Dictionary or not _text(checkpoint.get("step")) \
				or checkpoint.get("title") is not String or not _story(checkpoint.get("story")):
			return false
	return true

## Make a well-formed save match the episode as it is now. Records each change
## in last_notes. Always leaves at least one checkpoint.
static func _repair(data: Dictionary) -> void:
	var episode := load(data["episode"]) as TEEpisode
	var kept: Array = []
	var first_story: Dictionary = {}
	for checkpoint: Dictionary in data["checkpoints"]:
		_repair_story(checkpoint["story"], episode.manifest)
		if first_story.is_empty():
			first_story = checkpoint["story"]
		var step_id := StringName(checkpoint["step"])
		var renamed: Variant = episode.renamed_steps.get(step_id, episode.renamed_steps.get(String(step_id)))
		if renamed != null:
			_note("Checkpoint '%s' now starts at '%s'." % [step_id, renamed])
			step_id = StringName(renamed)
			checkpoint["step"] = step_id
		if episode.find(step_id) == null:
			_note("Checkpoint '%s' no longer exists and was dropped." % checkpoint["title"])
			continue
		kept.append(checkpoint)
	if kept.is_empty():
		# Nothing to return to: restart the episode, keeping what the story knew.
		_note("No checkpoint survived; the episode restarts from its beginning.")
		kept.append({"step": episode.entry, "title": episode.title, "story": first_story})
	data["checkpoints"] = kept

static func _repair_story(story: Dictionary, manifest: TEStoryManifest) -> void:
	var saved: Dictionary = story["vars"]
	var vars := {}
	for key: Variant in saved:
		var name := StringName(key)
		var renamed: Variant = manifest.renamed_variables.get(name, manifest.renamed_variables.get(String(name)))
		if renamed != null:
			_note("Variable '%s' is now '%s'." % [name, renamed])
			name = StringName(renamed)
		if not manifest.has_variable(name):
			_note("Variable '%s' is no longer used and was dropped." % name)
			continue
		var initial: Variant = manifest.initial(name)
		if initial != null and typeof(saved[key]) != typeof(initial):
			_note("Variable '%s' changed type and was reset." % name)
			vars[name] = initial
		else:
			vars[name] = saved[key]
	story["vars"] = vars
	var choices := {}
	for key: Variant in story["choices"]:
		if manifest.has_option(StringName(key), StringName(story["choices"][key])):
			choices[key] = story["choices"][key]
		else:
			_note("Choice '%s' no longer has option '%s' and was dropped." % [key, story["choices"][key]])
	story["choices"] = choices
	if story.has("items"):
		var kept_items := {}
		for key: Variant in story["items"]:
			if manifest.has_item(StringName(key)):
				kept_items[key] = int(story["items"][key])
			else:
				_note("Item '%s' no longer exists and was dropped." % key)
		story["items"] = kept_items

static func _note(text: String) -> void:
	if text not in last_notes:
		last_notes.append(text)

static func _season(info: Variant) -> bool:
	if info is not Dictionary or info.get("path") is not String or info.get("index") is not int:
		return false
	return info["path"].begins_with("res://") and ResourceLoader.exists(info["path"]) \
			and load(info["path"]) is TESeason and info["index"] >= 0

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
	if story.has("interactions"):
		if story.interactions is not Dictionary:
			return false
		for key in story.interactions:
			if not _text(key) or not CADEncounterRecord.valid(story.interactions[key]):
				return false
	for value: Variant in story["seen"].values():
		if value is not bool:
			return false
	if story.has("items"):
		if story["items"] is not Dictionary:
			return false
		for key: Variant in story["items"]:
			var count: Variant = story["items"][key]
			if not _text(key) or (count is not int and count is not float) or int(count) <= 0:
				return false
	return true
