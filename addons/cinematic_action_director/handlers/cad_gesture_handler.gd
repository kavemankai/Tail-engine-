class_name CADGestureHandler
extends CADInteractionHandler

var _holding := false
var _from := 0.0
var _pressed: Dictionary = {}
var _anchor := 0.0
var _anchored := false

func configure(value: CADInteractionSpec, offered: Array[CADOption]) -> void:
	super.configure(value, offered)
	_anchored = value.timing_marker == &""

func input(sample: CADInputSample) -> Dictionary:
	if sample.action not in spec.actions:
		return wrong() if sample.pressed else {}
	if spec.gesture == CADInteractionSpec.Gesture.CHORD:
		return _chord(sample)
	if spec.gesture == CADInteractionSpec.Gesture.PRESS:
		return _success() if sample.pressed else {}
	if sample.pressed:
		_holding = true
		_from = sample.at
	else:
		if spec.gesture == CADInteractionSpec.Gesture.TIMED_RELEASE and _holding:
			var result := CADTimingHandler.grade_at(spec, sample.at, _anchor + spec.ideal_seconds) if _anchored else wrong()
			reset_input()
			return result
		reset_input()
	return {}

func tick(elapsed: float, _delta: float) -> Dictionary:
	if spec.gesture == CADInteractionSpec.Gesture.CHORD and not _pressed.is_empty():
		if elapsed - float(_pressed.values().min()) > spec.chord_seconds + 0.0000001:
			reset_input()
			return wrong()
	if _holding and spec.gesture == CADInteractionSpec.Gesture.HOLD:
		progress = clampf((elapsed - _from) / spec.hold_seconds, 0.0, 1.0)
		if progress >= 1.0:
			return _success()
	return {}

func marker(id: StringName, at: float) -> bool:
	if id != spec.timing_marker or _anchored:
		return false
	_anchor = at
	_anchored = true
	return true

func _chord(sample: CADInputSample) -> Dictionary:
	if not sample.pressed:
		_pressed.erase(sample.action)
		progress = float(_pressed.size()) / spec.actions.size()
		return {}
	_pressed[sample.action] = sample.at
	progress = float(_pressed.size()) / spec.actions.size()
	if _pressed.size() == spec.actions.size():
		if float(_pressed.values().max()) - float(_pressed.values().min()) <= spec.chord_seconds + 0.0000001:
			return _success()
		reset_input()
		return wrong()
	return {}

func reset_input() -> void:
	_holding = false
	_pressed.clear()
	progress = 0.0

func _success() -> Dictionary:
	return {"grade": &"success", "option_id": spec.option_id, "progress": 1.0}
