class_name CADTimingHandler
extends CADInteractionHandler
## Timing and parry are the same evaluator; choreography supplies the ideal.

const EPSILON := 0.0000001
var _anchor := 0.0
var _anchored := false

func configure(value: CADInteractionSpec, offered: Array[CADOption]) -> void:
	super.configure(value, offered)
	_anchored = value.timing_marker == &""

func input(sample: CADInputSample) -> Dictionary:
	if not sample.pressed:
		return {}
	if sample.action != spec.actions[0] or not _anchored:
		return wrong()
	return grade_at(spec, sample.at, _anchor + spec.ideal_seconds)

func marker(id: StringName, at: float) -> bool:
	if id != spec.timing_marker or _anchored:
		return false
	_anchor = at
	_anchored = true
	return true

static func grade_at(value: CADInteractionSpec, at: float, target: float) -> Dictionary:
	var error := at - target
	var distance := absf(error)
	if error < -value.partial_seconds - EPSILON and value.wrong_input == CADInteractionSpec.WrongInput.IGNORE:
		return {}
	var grade := &"miss"
	if distance <= value.perfect_seconds + EPSILON:
		grade = &"perfect"
	elif distance <= value.success_seconds + EPSILON:
		grade = &"success"
	elif distance <= value.partial_seconds + EPSILON:
		grade = &"partial"
	return {"grade": grade, "option_id": value.option_id if grade != &"miss" else &"",
		"timing_error_ms": error * 1000.0, "progress": 1.0 if grade != &"miss" else 0.0}
