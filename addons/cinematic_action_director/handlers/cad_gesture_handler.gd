class_name CADGestureHandler
extends CADInteractionHandler

var _holding := false
var _from := 0.0

func input(sample: CADInputSample) -> Dictionary:
	if sample.action != spec.actions[0]:
		return wrong() if sample.pressed else {}
	if spec.gesture == CADInteractionSpec.Gesture.PRESS:
		return _success() if sample.pressed else {}
	if sample.pressed:
		_holding = true
		_from = sample.at
	else:
		reset_input()
	return {}

func tick(elapsed: float, _delta: float) -> Dictionary:
	if _holding:
		progress = clampf((elapsed - _from) / spec.hold_seconds, 0.0, 1.0)
		if progress >= 1.0:
			return _success()
	return {}

func reset_input() -> void:
	_holding = false
	progress = 0.0

func _success() -> Dictionary:
	return {"grade": &"success", "option_id": spec.option_id, "progress": 1.0}
