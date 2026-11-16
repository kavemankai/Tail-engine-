class_name CADCounterattackTemplate
extends CADCompoundAction
## defence -> evade -> counter -> land/recover, or defence -> hit_reaction.
## A missed counter preserves the successful defence. Gates and six authored
## timelines are reusable; this class owns no input, actors, camera or Story.

@export var defence: CADGate
@export var counter: CADGate
@export var defence_timeline: StringName
@export var evade_timeline: StringName
@export var hit_timeline: StringName
@export var counter_timeline: StringName
@export var land_timeline: StringName
@export var recover_timeline: StringName
@export var countered_outcome := &"countered"
@export var defended_outcome := &"defended"
@export var hit_outcome := &"hit"
@export_range(0.0, 2.0) var blend_seconds := 0.08

func build() -> CADSequence:
	last_errors.clear()
	if defence == null or counter == null:
		last_errors.append("Counterattack needs defence and counter gates.")
	else:
		_grade_routes(defence, &"evade", &"hit_reaction")
		_grade_routes(counter, &"land", &"recover")
	for timeline in [defence_timeline, evade_timeline, hit_timeline, counter_timeline, land_timeline, recover_timeline]:
		if timeline == &"":
			last_errors.append("Counterattack needs all six authored timelines.")
	if not is_finite(blend_seconds) or blend_seconds < 0.0 or blend_seconds > 2.0:
		last_errors.append("Counterattack blend must be finite and between 0 and 2 seconds.")
	if not last_errors.is_empty():
		return null
	var sequence := CADSequence.new()
	sequence.entry = &"defence"
	sequence.outcomes = [countered_outcome, defended_outcome, hit_outcome]
	sequence.beats = [
		_beat(&"defence", defence_timeline, &"", _wire(defence, &"evade", &"hit_reaction")),
		_beat(&"evade", evade_timeline, &"counter"),
		_beat(&"hit_reaction", hit_timeline, hit_outcome),
		_beat(&"counter", counter_timeline, &"", _wire(counter, &"land", &"recover")),
		_beat(&"land", land_timeline, countered_outcome),
		_beat(&"recover", recover_timeline, defended_outcome),
	]
	last_errors = sequence.validation_errors()
	return sequence if last_errors.is_empty() else null

func _wire(source: CADGate, success: StringName, failure: StringName) -> CADGate:
	var gate: CADGate = source.duplicate(true)
	for option in gate.options:
		if option != null:
			option.next = success
	gate.timeout_next = failure
	# Grade policies choose between the component's two authored reactions;
	# arbitrary graph composition stays available through plain CADSequence.
	return gate

func _grade_routes(gate: CADGate, success: StringName, failure: StringName) -> void:
	if gate.interaction == null:
		return
	for destination: StringName in gate.interaction.routes.values():
		if destination not in [success, failure]:
			last_errors.append("Counterattack grade route '%s' must choose '%s' or '%s'; loops and skipped reactions are not supported." % [destination, success, failure])

func _beat(id: StringName, timeline: StringName, next: StringName, gate: CADGate = null) -> CADBeat:
	var beat := CADBeat.new()
	beat.id = id
	beat.timeline = timeline
	beat.next = next
	beat.gate = gate
	beat.blend_seconds = blend_seconds
	return beat
