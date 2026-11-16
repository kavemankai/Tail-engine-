class_name CADSequence
extends Resource
## A graph of beats. Every exit names a beat ID or a terminal outcome.

const RESERVED: Array[StringName] = [&"cancelled", &"watchdog", &"staging_error"]

@export var entry: StringName
@export var beats: Array[CADBeat] = []
@export var outcomes: Array[StringName] = []
@export_range(0, 100) var momentum_limit := 3
@export_range(0, 100) var momentum_start := 0
## Declared actor roles/statuses and prop availability for typed predicates.
@export var actor_statuses: Dictionary[StringName, StringName] = {}
@export var prop_states: Dictionary[StringName, bool] = {}

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if momentum_limit < 0 or momentum_limit > 100 or momentum_start < 0 or momentum_start > momentum_limit:
		errors.append("Encounter momentum must start within its 0–100 bound.")
	for role in actor_statuses:
		if role == &"" or actor_statuses[role] == &"":
			errors.append("Actor context needs nonempty role/status IDs.")
	for id in prop_states:
		if id == &"":
			errors.append("Prop context needs nonempty IDs.")
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
		if not is_finite(beat.playback_scale) or beat.playback_scale < 0.05 or beat.playback_scale > 4.0:
			errors.append("Beat %s: playback_scale must be finite and between 0.05 and 4." % beat.id)
		for role in beat.actor_changes:
			if not actor_statuses.has(role) or beat.actor_changes[role] == &"":
				errors.append("Beat %s changes an undeclared/empty actor status." % beat.id)
		for id in beat.prop_changes:
			if not prop_states.has(id):
				errors.append("Beat %s changes an undeclared prop state." % beat.id)
		var exits: Array[StringName] = []
		if beat.gate == null:
			exits.append(beat.next)
			for branch in beat.branches:
				if branch == null or (branch.requires == &"" and branch.predicate == null):
					errors.append("Beat %s has an empty branch." % beat.id)
				else:
					exits.append(branch.next)
					if branch.predicate != null:
						errors.append_array(branch.predicate.validation_errors(self))
		else:
			exits.append(beat.gate.timeout_next)
			if beat.gate.interaction != null:
				if beat.gate.interaction.timing_marker != &"" and beat.gate.interaction.timing_marker == beat.gate.open_marker:
					errors.append("Beat %s: timing anchor must follow gate opening; use an empty timing_marker for gate-relative timing." % beat.id)
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
