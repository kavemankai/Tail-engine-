class_name TEValidator
extends RefCounted
## Checks an episode without playing it. Returns one line per problem.

static func check(episode: TEEpisode) -> PackedStringArray:
	var errors := PackedStringArray()
	if episode.manifest == null or episode.cast == null:
		errors.append("Episode needs a manifest and a cast.")
		return errors
	var variables: Dictionary = episode.manifest.variables
	var ids: Dictionary = {}
	for step in episode.steps:
		if step == null or step.id == &"" or ids.has(step.id):
			errors.append("Empty or duplicate step id: %s" % (step.id if step != null else &""))
		elif step.id == Flow.END:
			errors.append("A step cannot be called END.")
		else:
			ids[step.id] = step
	if not ids.has(episode.entry):
		errors.append("Entry '%s' is not a step." % episode.entry)
	if episode.cast.find(episode.player) == null:
		errors.append("Player character '%s' is not in the cast." % episode.player)
	for character in episode.cast.characters:
		if character.actor_scene != null:
			var actor := character.actor_scene.instantiate()
			if actor is not TEActor:
				errors.append("Character '%s': actor scene root must extend TEActor." % character.id)
			actor.free()

	var locations: Dictionary = {}
	var current_location: Dictionary = {}
	_assign_locations(episode, ids, current_location)
	for step: TEStep in ids.values():
		var where := "Step %s" % step.id
		# Exits.
		if step.exits.is_empty():
			errors.append("%s has no exits." % where)
		for exit in step.exits:
			if exit.next != Flow.END and not ids.has(exit.next):
				errors.append("%s exits to missing step '%s'." % [where, exit.next])
			var problem := TECondition.error(exit.when, variables)
			if problem != "":
				errors.append("%s exit condition '%s': %s" % [where, exit.when, problem])
			check_items(exit.when, episode.manifest, "%s exit condition" % where, errors)
		if step.music != null and step.stop_music:
			errors.append("%s both sets and stops the music." % where)
		if step.ambience != null and step.stop_ambience:
			errors.append("%s both sets and stops the ambience." % where)
		# Location and cast.
		var path: String = current_location.get(step.id, "")
		var location: TELocation = null
		if path != "":
			if not locations.has(path):
				var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
				locations[path] = scene.instantiate() if scene != null else null
			location = locations[path] as TELocation
			if location == null:
				errors.append("%s: '%s' is not a scene with a TELocation root." % [where, path])
		elif step.kind != TEStep.Kind.CARD:
			errors.append("%s has no location." % where)
		for id: StringName in step.cast:
			if episode.cast.find(id) == null:
				errors.append("%s casts unknown character '%s'." % [where, id])
			if location != null and step.cast[id] != "" and location.mark(step.cast[id]) == null:
				errors.append("%s uses missing mark '%s'." % [where, step.cast[id]])
		# Payload.
		var named_exits: Array = []
		match step.kind:
			TEStep.Kind.DIALOGUE:
				named_exits = _check_dialogue(step.dialogue, [step.cue], episode, where, errors)
				if location != null and step.shot != &"" and location.shot(step.shot) == null:
					errors.append("%s uses missing shot '%s'." % [where, step.shot])
				_check_shots(step.dialogue, [step.cue], location, where, errors)
			TEStep.Kind.CUTSCENE:
				named_exits = [&"end"]
				if step.cues.is_empty():
					errors.append("%s is a cutscene with no cues." % where)
				for cue in step.cues:
					if cue == null:
						errors.append("%s has an empty cue." % where)
						continue
					if location != null and location.shot(cue.shot) == null:
						errors.append("%s cue uses missing shot '%s'." % [where, cue.shot])
					if cue.speaker != &"" and episode.cast.find(cue.speaker) == null:
						errors.append("%s cue speaker '%s' is not in the cast." % [where, cue.speaker])
					for id: StringName in cue.clips:
						var clip_issue := clip_problem(episode, id, StringName(cue.clips[id]))
						if clip_issue != "":
							errors.append("%s cue %s" % [where, clip_issue])
					for id: StringName in cue.emotes:
						if episode.cast.find(id) == null:
							errors.append("%s cue sets the emotion of unknown character '%s'." % [where, id])
					if cue.wait_for_clip != &"" and episode.cast.find(cue.wait_for_clip) == null:
						errors.append("%s cue waits for unknown character '%s'." % [where, cue.wait_for_clip])
					if cue.voice != null and cue.speaker == &"":
						errors.append("%s cue has a voice but no speaker." % where)
			TEStep.Kind.TIMELINE:
				named_exits = [&"end"]
				var player := location.get_node_or_null(step.timeline_player) as AnimationPlayer if location != null else null
				if player == null:
					errors.append("%s needs an AnimationPlayer at '%s' in its location." % [where, step.timeline_player])
				elif not player.has_animation(step.timeline):
					errors.append("%s: the AnimationPlayer has no animation '%s'." % [where, step.timeline])
				else:
					_check_timeline(player, player.get_animation(step.timeline), location, episode, where, errors)
			TEStep.Kind.ENCOUNTER:
				var stage := location.stage(step.stage) if location != null else null
				var sequence := step.resolve_sequence()
				if step.sequence != null and step.compound != null:
					errors.append("%s: choose sequence or compound, not both." % where)
				elif step.compound != null and sequence == null:
					for problem in step.compound.last_errors:
						errors.append("%s compound: %s" % [where, problem])
				if sequence == null or stage == null:
					errors.append("%s needs a sequence and a stage named '%s' in its location." % [where, step.stage])
				else:
					for problem in CADDirector.validation_errors(sequence, stage):
						errors.append("%s: %s" % [where, problem])
					for role: StringName in step.roles:
						if stage.slot(role) == null:
							errors.append("%s binds missing stage role '%s'." % [where, role])
						if episode.cast.find(step.roles[role]) == null:
							errors.append("%s binds unknown character '%s'." % [where, step.roles[role]])
					named_exits = sequence.outcomes.duplicate()
			TEStep.Kind.EXPLORE:
				var hub := location.hub(step.hub) if location != null else null
				if hub == null:
					errors.append("%s needs a hub named '%s' in its location." % [where, step.hub])
				else:
					var cues: Array = []
					for hotspot in hub.hotspots():
						var problem := TECondition.error(hotspot.when, variables)
						if problem != "":
							errors.append("%s hotspot %s condition: %s" % [where, hotspot.name, problem])
						check_items(hotspot.when, episode.manifest, "%s hotspot %s" % [where, hotspot.name], errors)
						if hotspot.requires_item != &"" and not episode.manifest.has_item(hotspot.requires_item):
							errors.append("%s hotspot %s needs undeclared item '%s'." % [where, hotspot.name, hotspot.requires_item])
						if hotspot.missing_item_cue != "":
							cues.append(hotspot.missing_item_cue)
						if hotspot.examine_scene != null:
							var model := hotspot.examine_scene.instantiate()
							if model is not Node3D:
								errors.append("%s hotspot %s: examine scene root must be a Node3D." % [where, hotspot.name])
							model.free()
						if hotspot.cue != "":
							cues.append(hotspot.cue)
						if hotspot.exit != &"":
							named_exits.append(hotspot.exit)
					if not cues.is_empty():
						named_exits.append_array(_check_dialogue(hub.dialogue, cues, episode, where, errors))
						_check_shots(hub.dialogue, cues, location, where, errors)
					named_exits.erase(TEBalloon.DEFAULT_EXIT)
					if named_exits.is_empty():
						errors.append("%s: no hotspot can end the step." % where)
				if not step.cast.has(episode.player) and not _cast_earlier(episode, ids, step, current_location):
					errors.append("%s needs the player in its cast." % where)
		# Every way the step can end needs somewhere to go.
		for exit_name: StringName in named_exits:
			var covered := false
			for exit in step.exits:
				if (exit.on == &"*" or exit.on == exit_name) and exit.when.strip_edges() == "":
					covered = true
			if not covered:
				errors.append("%s can end with '%s' but has no unconditional exit for it." % [where, exit_name])

	for step_id: StringName in ids:
		if not current_location.has(step_id):
			errors.append("Step %s cannot be reached from the entry." % step_id)
	for location: Variant in locations.values():
		if location != null:
			location.free()
	# A dialogue file shared by several steps reports each problem once.
	var unique := PackedStringArray()
	for problem in errors:
		if problem not in unique:
			unique.append(problem)
	return unique

## Checks that read Dialogue Manager's compiled lines rather than the source
## text: speakers, response counts, and the values of #timed and #clip tags.
static func _check_lines(resource: DialogueResource, episode: TEEpisode, errors: PackedStringArray) -> void:
	var path := resource.resource_path if resource.resource_path != "" else "dialogue"
	var reported: Dictionary = {}
	for id: Variant in resource.lines:
		var line: Dictionary = resource.lines[id]
		var kind := String(line.get("type", ""))
		var speaker := String(line.get("character", ""))
		if kind == "dialogue" and speaker != "" and episode.cast.find(StringName(speaker)) == null and not reported.has(speaker):
			reported[speaker] = true
			errors.append("%s: speaker '%s' is not in the cast." % [path, speaker])
		var responses: Array = line.get("responses", [])
		if kind == "response" and responses.size() > TEBalloon.CHOICE_ACTIONS.size():
			errors.append("%s: '%s' starts a choice of %d responses; only %d have buttons unless highlight-and-confirm is on." \
				% [path, line.get("text", ""), responses.size(), TEBalloon.CHOICE_ACTIONS.size()])
		for tag: String in line.get("tags", []):
			var value := tag.get_slice("=", 1) if tag.contains("=") else ""
			if tag.begins_with("timed="):
				if not value.is_valid_float() or value.to_float() <= 0.0:
					errors.append("%s: '%s' has #timed=%s; it needs a number of seconds above zero." % [path, line.get("text", ""), value])
			elif tag.begins_with("clip="):
				var who := StringName(value.get_slice(":", 0)) if value.contains(":") else StringName(speaker)
				var clip := StringName(value.get_slice(":", 1) if value.contains(":") else value)
				var problem := clip_problem(episode, who, clip)
				if problem != "":
					errors.append("%s: [#clip=%s] %s" % [path, value, problem])
			elif tag.begins_with("look=") and value != "none" and value != "" and episode.cast.find(StringName(value)) == null:
				# Marks are checked where the location is known; a cast id is checked here.
				if not value.is_valid_identifier():
					errors.append("%s: [#look=%s] is not a character, mark or none." % [path, value])

## Empty if `clip` can be played on `who`; otherwise why not. A character
## with no clip map accepts any name, since its scene may play real names.
static func clip_problem(episode: TEEpisode, who: StringName, clip: StringName) -> String:
	var character := episode.cast.find(who)
	if character == null:
		return "names unknown character '%s'." % who
	if not character.clips.is_empty() and not character.clips.has(clip) and not character.clips.has(String(clip)):
		return "'%s' has no clip '%s' in its clip map." % [who, clip]
	return ""

## Item ids named by give/take/has_item/item_count must be declared.
static func check_items(text: String, manifest: TEStoryManifest, where: String, errors: PackedStringArray) -> void:
	var regex := RegEx.new()
	regex.compile("\\b(?:give|take|has_item|item_count)\\(\\s*[\"']([^\"']+)[\"']")
	for found in regex.search_all(text):
		if not manifest.has_item(found.get_string(1)):
			errors.append("%s: uses undeclared item '%s'." % [where, found.get_string(1)])

## Method tracks aimed at a TETimelineCues node must call its methods, and
## name shots and characters that exist.
static func _check_timeline(player: AnimationPlayer, animation: Animation, location: TELocation, episode: TEEpisode,
		where: String, errors: PackedStringArray) -> void:
	var root := player.get_node_or_null(player.root_node)
	var with_character := ["clip", "voice", "emote", "gesture", "look"]
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		var target := root.get_node_or_null(animation.track_get_path(track)) if root != null else null
		if target == null:
			errors.append("%s: timeline method track points at missing node '%s'." % [where, animation.track_get_path(track)])
			continue
		if target is not TETimelineCues:
			continue
		for key in animation.track_get_key_count(track):
			var method := String(animation.method_track_get_name(track, key))
			var args := animation.method_track_get_params(track, key)
			if not target.has_method(method) or method.begins_with("_"):
				errors.append("%s: timeline calls unknown cue '%s'." % [where, method])
			elif method == "shot" and (args.is_empty() or location.shot(StringName(str(args[0]))) == null):
				errors.append("%s: timeline cuts to missing shot '%s'." % [where, args[0] if not args.is_empty() else ""])
			elif method in with_character and (args.is_empty() or episode.cast.find(StringName(str(args[0]))) == null):
				errors.append("%s: timeline cue '%s' names unknown character '%s'." % [where, method, args[0] if not args.is_empty() else ""])

## Walk the graph from the entry, recording which location each step runs in.
static func _assign_locations(episode: TEEpisode, ids: Dictionary, found: Dictionary) -> void:
	var queue: Array = [[episode.entry, ""]]
	while not queue.is_empty():
		var item: Array = queue.pop_back()
		if not ids.has(item[0]) or found.has(item[0]):
			continue
		var step: TEStep = ids[item[0]]
		var path: String = step.location if step.location != "" else item[1]
		found[step.id] = path
		for exit in step.exits:
			queue.append([exit.next, path])

static func _cast_earlier(episode: TEEpisode, ids: Dictionary, target: TEStep, locations: Dictionary) -> bool:
	for step: TEStep in ids.values():
		if step != target and step.cast.has(episode.player) and locations.get(step.id) == locations.get(target.id):
			return true
	return false

## Checks cues exist and that the file's Story calls use declared names.
## Returns the exit names the file can produce.
static func _check_dialogue(resource: DialogueResource, cues: Array, episode: TEEpisode, where: String,
		errors: PackedStringArray) -> Array:
	if resource == null:
		errors.append("%s has no dialogue file." % where)
		return []
	var known := resource.get_cues()
	for cue: String in cues:
		if cue not in known:
			errors.append("%s uses missing dialogue cue '%s'." % [where, cue])
	var text := _reachable_text(resource, cues)
	var regex := RegEx.new()
	regex.compile("Story\\.(flag|value|put|add|remember)\\(\\s*\"([^\"]+)\"")
	for found in regex.search_all(text):
		if not episode.manifest.has_variable(found.get_string(2)):
			errors.append("%s: dialogue uses undeclared variable '%s'." % [resource.resource_path, found.get_string(2)])
	check_items(text, episode.manifest, resource.resource_path, errors)
	regex.compile("Story\\.choose\\(\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"")
	for found in regex.search_all(text):
		if not episode.manifest.has_option(found.get_string(1), found.get_string(2)):
			errors.append("%s: dialogue logs undeclared choice '%s' / '%s'." % [resource.resource_path, found.get_string(1), found.get_string(2)])
	_check_lines(resource, episode, errors)
	var exits: Array = [TEBalloon.DEFAULT_EXIT]
	regex.compile("\\bexit\\(\\s*\"([^\"]+)\"")
	for found in regex.search_all(text):
		if StringName(found.get_string(1)) not in exits:
			exits.append(StringName(found.get_string(1)))
	return exits

static func _check_shots(resource: DialogueResource, cues: Array, location: TELocation, where: String, errors: PackedStringArray) -> void:
	if resource == null or location == null:
		return
	var regex := RegEx.new()
	regex.compile("#shot=(\\w+)")
	var reported: Dictionary = {}
	for found in regex.search_all(_reachable_text(resource, cues)):
		var shot := found.get_string(1)
		if location.shot(shot) == null and not reported.has(shot):
			reported[shot] = true
			errors.append("%s: dialogue uses missing shot '%s'." % [where, shot])

## The source text of the given cues plus every cue they jump to.
static func _reachable_text(resource: DialogueResource, cues: Array) -> String:
	var sections: Dictionary = {}
	var current := ""
	for line in FileAccess.get_file_as_string(resource.resource_path).split("\n"):
		if line.begins_with("~ "):
			current = line.substr(2).strip_edges()
			sections[current] = ""
		elif current != "":
			sections[current] += line + "\n"
	var jump := RegEx.new()
	jump.compile("=><?\\s*(\\w+)")
	var text := ""
	var queue := cues.duplicate()
	var done: Dictionary = {}
	while not queue.is_empty():
		var cue: String = queue.pop_back()
		if done.has(cue) or not sections.has(cue):
			continue
		done[cue] = true
		text += sections[cue]
		for found in jump.search_all(sections[cue]):
			queue.append(found.get_string(1))
	return text

## How many dialogue lines with an [ID:...] have a voice file, as [voiced, total].
static func voice_coverage(episode: TEEpisode) -> Array:
	return TEVoice.coverage(episode)
