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
	return errors

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
	regex.compile("Story\\.choose\\(\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"")
	for found in regex.search_all(text):
		if not episode.manifest.has_option(found.get_string(1), found.get_string(2)):
			errors.append("%s: dialogue logs undeclared choice '%s' / '%s'." % [resource.resource_path, found.get_string(1), found.get_string(2)])
	regex.compile("^\\s*(\\w+):", )
	for line in text.split("\n"):
		var speaker := regex.search(line)
		if speaker != null and not line.strip_edges().begins_with("-") and episode.cast.find(speaker.get_string(1)) == null:
			errors.append("%s: speaker '%s' is not in the cast." % [resource.resource_path, speaker.get_string(1)])
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
	var seen: Dictionary = {}
	var voiced := 0
	var total := 0
	var regex := RegEx.new()
	regex.compile("^\\s*(\\w+):.*\\[ID:(\\w+)\\]")
	for step in episode.steps:
		if step.dialogue == null or seen.has(step.dialogue.resource_path):
			continue
		seen[step.dialogue.resource_path] = true
		for line in FileAccess.get_file_as_string(step.dialogue.resource_path).split("\n"):
			var found := regex.search(line)
			if found == null:
				continue
			total += 1
			var character := episode.cast.find(found.get_string(1))
			if character != null and character.voice_dir != "":
				for extension: String in ["ogg", "wav", "mp3"]:
					if ResourceLoader.exists("%s/%s.%s" % [character.voice_dir, found.get_string(2), extension]):
						voiced += 1
						break
	return [voiced, total]
