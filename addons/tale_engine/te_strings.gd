class_name TEStrings
extends RefCounted
## Collects every translatable string for a translation template (.pot).
##
## Engine text is translated with tr() where it is shown; the source string is
## the key. Content text (titles, cards, captions, hotspot verbs, recap
## sentences, names, action prompts) is translated the same way, so a .po file
## whose msgid is the English text translates it. Dialogue lines are handled by
## Dialogue Manager through their [ID:...] and are not collected here.
##
## A development tool: it reads script sources, which an exported game may not
## contain.

const ENGINE_DIRS: Array[String] = ["res://addons/tale_engine", "res://addons/cinematic_action_director"]

## Every string the engine's own UI can show.
static func engine() -> PackedStringArray:
	var found := {}
	var pattern := RegEx.new()
	# tr("...") in nodes and _t("...") in static code.
	pattern.compile("\\b(?:tr|_t)\\(\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for directory in ENGINE_DIRS:
		for path in _scripts(directory):
			for hit in pattern.search_all(FileAccess.get_file_as_string(path)):
				found[hit.get_string(1).c_unescape()] = true
	for label: String in TEBindings.LABELS.values():
		found[label] = true
	for phrase: String in CADPrompt.PHRASES:
		found[phrase] = true
	return _sorted(found)

## Every authored string of an episode that the player can read.
static func content(episode: TEEpisode) -> PackedStringArray:
	var found := {}
	if episode == null:
		return PackedStringArray()
	_add(found, episode.title)
	if episode.cast != null:
		for character in episode.cast.characters:
			if character != null:
				_add(found, character.display_name)
	if episode.manifest != null:
		for options: Variant in episode.manifest.choices.values():
			if options is Dictionary:
				for sentence: Variant in options.values():
					_add(found, String(sentence))
	var locations := {}
	for step in episode.steps:
		if step == null:
			continue
		_add(found, step.title)
		_add(found, step.heading)
		_add(found, step.body)
		for cue in step.cues:
			if cue != null:
				_add(found, cue.caption)
		var sequence := step.resolve_sequence() if step.kind == TEStep.Kind.ENCOUNTER else null
		if sequence != null:
			for beat in sequence.beats:
				if beat != null and beat.gate != null:
					for option in beat.gate.options:
						if option != null:
							_add(found, option.label)
		if step.location != "":
			locations[step.location] = true
	for path: String in locations:
		_scan_scene(path, found)
	return _sorted(found)

## A gettext template. `sources` maps a comment to the strings found there.
static func to_pot(sources: Dictionary) -> String:
	var text := "msgid \"\"\nmsgstr \"\"\n\"Content-Type: text/plain; charset=UTF-8\\n\"\n"
	var written := {}
	for comment: String in sources:
		for source: String in sources[comment]:
			if written.has(source):
				continue
			written[source] = true
			text += "\n#. %s\nmsgid \"%s\"\nmsgstr \"\"\n" % [comment, source.c_escape()]
	return text

## Hotspot verbs and bark lines live in the location scene.
static func _scan_scene(path: String, found: Dictionary) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var root := scene.instantiate() if scene != null else null
	if root == null:
		return
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is TEHotspot:
			_add(found, node.label)
		elif node is CADStage:
			for bark in node.barks:
				if bark != null:
					_add(found, bark.text)
		pending.append_array(node.get_children())
	root.free()

static func _add(found: Dictionary, text: String) -> void:
	if text.strip_edges() != "":
		found[text] = true

static func _sorted(found: Dictionary) -> PackedStringArray:
	var keys := PackedStringArray(found.keys())
	keys.sort()
	return keys

static func _scripts(directory: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(directory)
	if dir == null:
		return paths
	for file in dir.get_files():
		if file.ends_with(".gd"):
			paths.append(directory.path_join(file))
	for child in dir.get_directories():
		paths.append_array(_scripts(directory.path_join(child)))
	return paths
