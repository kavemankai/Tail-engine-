class_name TEVoice
extends RefCounted
## Voice-over bookkeeping: which lines an episode has, who speaks them, and
## which recordings exist. Recordings are named <voice_dir>/<line id>.ogg|wav|mp3.

const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]

## One entry per dialogue line that has an [ID:...] tag:
## { id, character, text, path (existing recording or ""), expected (path to record to) }.
static func lines(episode: TEEpisode) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("^\\s*(\\w+):\\s*(.*?)\\s*(?:\\[#[^\\]]*\\]\\s*)*\\[ID:(\\w+)\\]")
	for step in episode.steps:
		if step == null or step.dialogue == null or seen.has(step.dialogue.resource_path):
			continue
		seen[step.dialogue.resource_path] = true
		for raw in FileAccess.get_file_as_string(step.dialogue.resource_path).split("\n"):
			var found := regex.search(raw)
			if found == null:
				continue
			var character := episode.cast.find(StringName(found.get_string(1)))
			var line_id := found.get_string(3)
			var directory := character.voice_dir if character != null else ""
			result.append({
				"id": line_id,
				"character": found.get_string(1),
				"text": found.get_string(2).strip_edges(),
				"path": _recording(directory, line_id),
				"expected": "%s/%s.ogg" % [directory, line_id] if directory != "" else "",
			})
	return result

static func _recording(directory: String, line_id: String) -> String:
	if directory == "":
		return ""
	for extension in EXTENSIONS:
		var path := "%s/%s.%s" % [directory, line_id, extension]
		if ResourceLoader.exists(path):
			return path
	return ""

## [voiced, total]
static func coverage(episode: TEEpisode) -> Array:
	var all := lines(episode)
	var voiced := 0
	for entry in all:
		if entry["path"] != "":
			voiced += 1
	return [voiced, all.size()]

## Recording script for actors: one CSV row per line, in episode order.
static func to_csv(episode: TEEpisode) -> String:
	var rows := PackedStringArray(["line_id,character,text,recorded,file"])
	for entry in lines(episode):
		rows.append(",".join([entry["id"], entry["character"], _quote(entry["text"]),
			"yes" if entry["path"] != "" else "no", _quote(entry["expected"])]))
	return "\n".join(rows) + "\n"

static func _quote(text: String) -> String:
	return "\"%s\"" % text.replace("\"", "\"\"")
