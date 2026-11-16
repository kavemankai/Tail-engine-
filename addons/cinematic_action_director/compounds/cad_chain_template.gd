class_name CADChainTemplate
extends CADCompoundAction
## Each gate selects an authored action/reaction before the next gate opens.
## Attack/defence chains and combos share this compiler, not a second runner.
## Beat IDs are input_N/action_N/recover_N (one-based). A failed component
## performs its own recovery and terminates; earlier results remain intact.

@export var gates: Array[CADGate] = []
@export var input_timelines: Array[StringName] = []
@export var action_timelines: Array[StringName] = []
@export var recovery_timelines: Array[StringName] = []
@export var completed_outcome := &"completed"
@export var interrupted_outcome := &"interrupted"
@export_range(0.0, 2.0) var blend_seconds := 0.08

func build() -> CADSequence:
	last_errors.clear()
	if gates.is_empty() or gates.size() > 32 or input_timelines.size() != gates.size() \
			or action_timelines.size() != gates.size() or recovery_timelines.size() != gates.size():
		last_errors.append("Chain needs 1–32 gates and one input/action/recovery timeline per gate.")
	if not is_finite(blend_seconds) or blend_seconds < 0.0 or blend_seconds > 2.0:
		last_errors.append("Chain blend must be finite and between 0 and 2 seconds.")
	if not last_errors.is_empty():
		return null
	var sequence := CADSequence.new()
	sequence.entry = &"input_1"
	sequence.outcomes = [completed_outcome, interrupted_outcome]
	for i in gates.size():
		var number := str(i + 1)
		var success := StringName("action_" + number)
		var failure := StringName("recover_" + number)
		if gates[i] == null or input_timelines[i] == &"" or action_timelines[i] == &"" or recovery_timelines[i] == &"":
			last_errors.append("Chain component %s needs a gate and all three timelines." % number)
			continue
		var gate: CADGate = gates[i].duplicate(true)
		for option in gate.options:
			if option != null:
				option.next = success
		gate.timeout_next = failure
		if gate.interaction != null:
			for destination: StringName in gate.interaction.routes.values():
				if destination not in [success, failure]:
					last_errors.append("Chain component %s grade routes must select %s or %s." % [number, success, failure])
		sequence.beats.append(_beat(StringName("input_" + number), input_timelines[i], &"", gate))
		sequence.beats.append(_beat(success, action_timelines[i], StringName("input_" + str(i + 2)) if i + 1 < gates.size() else completed_outcome))
		sequence.beats.append(_beat(failure, recovery_timelines[i], interrupted_outcome))
	last_errors.append_array(sequence.validation_errors())
	return sequence if last_errors.is_empty() else null

func _beat(id: StringName, timeline: StringName, next: StringName, gate: CADGate = null) -> CADBeat:
	var beat := CADBeat.new()
	beat.id = id
	beat.timeline = timeline
	beat.next = next
	beat.gate = gate
	beat.blend_seconds = blend_seconds
	return beat
