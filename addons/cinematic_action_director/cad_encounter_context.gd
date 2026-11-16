class_name CADEncounterContext
extends RefCounted
## Per-run authored state. No node references, arbitrary expressions or Story
## mutation. Hosts commit snapshots only at safe encounter/checkpoint boundaries.

var momentum := 0
var limit := 3
var intent: StringName
var actor_statuses: Dictionary[StringName, StringName] = {}
var prop_states: Dictionary[StringName, bool] = {}

func configure(sequence: CADSequence) -> void:
	limit = sequence.momentum_limit
	momentum = sequence.momentum_start
	intent = &""
	actor_statuses = sequence.actor_statuses.duplicate()
	prop_states = sequence.prop_states.duplicate()

func apply(result: CADResult) -> void:
	if result.grade == &"cancelled":
		return
	momentum = clampi(momentum + result.momentum_delta, 0, limit)
	if result.intent_id != &"":
		intent = result.intent_id

func enter(beat: CADBeat) -> void:
	actor_statuses.merge(beat.actor_changes, true)
	prop_states.merge(beat.prop_changes, true)

func to_dict() -> Dictionary:
	var actors := {}
	for role in actor_statuses:
		actors[String(role)] = String(actor_statuses[role])
	var props := {}
	for id in prop_states:
		props[String(id)] = prop_states[id]
	return {"momentum": momentum, "limit": limit, "intent": String(intent), "actors": actors, "props": props}
