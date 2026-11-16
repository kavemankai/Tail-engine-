class_name CADSequence
extends Resource
## A graph of beats. Every exit names a beat ID or a terminal outcome.

const RESERVED: Array[StringName] = [&"cancelled", &"watchdog", &"staging_error"]

@export var entry: StringName
@export var beats: Array[CADBeat] = []
@export var outcomes: Array[StringName] = []

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var destinations: Dictionary = {}
	for outcome in outcomes:
		if outcome == &"" or destinations.has(outcome) or outcome in RESERVED:
			errors.append("Invalid or duplicate outcome: %s" % outcome)
		destinations[outcome] = true
	var beat_ids: Dictionary = {}
	for beat in beats:
		if beat == null:
			errors.append("Sequence contains an empty beat.")
			continue
		if beat.id == &"" or destinations.has(beat.id):
			errors.append("Invalid or duplicate beat ID: %s" % beat.id)
		beat_ids[beat.id] = true
		destinations[beat.id] = true
	if not beat_ids.has(entry):
		errors.append("Entry %s does not identify a beat." % entry)
	for beat in beats:
		if beat == null:
			continue
		var exits: Array[StringName] = []
		if beat.gate == null:
			exits.append(beat.next)
			for branch in beat.branches:
				if branch == null or branch.requires == &"":
					errors.append("Beat %s has an empty branch." % beat.id)
				else:
					exits.append(branch.next)
		else:
			exits.append(beat.gate.timeout_next)
			if beat.gate.interaction != null:
				for problem in beat.gate.interaction.validation_errors(beat.gate.options, beat.gate.window_seconds):
					errors.append("Beat %s: %s" % [beat.id, problem])
				for destination in beat.gate.interaction.routes.values():
					exits.append(destination)
			var option_ids: Dictionary = {}
			for option in beat.gate.options:
				if option == null or option.id == &"" or option.id == &"timeout" \
						or option.action == &"" or option_ids.has(option.id):
					errors.append("Beat %s has an empty, duplicate or incomplete gate option." % beat.id)
					continue
				option_ids[option.id] = true
				exits.append(option.next)
		for destination in exits:
			if not destinations.has(destination):
				errors.append("Beat %s references missing destination '%s'." % [beat.id, destination])
		if not beat.ends_by_itself() and beat.watchdog_seconds <= 0.0:
			errors.append("Beat %s is host-driven and needs watchdog_seconds." % beat.id)
	return errors
