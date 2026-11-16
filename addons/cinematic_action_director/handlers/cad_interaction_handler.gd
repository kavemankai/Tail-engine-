class_name CADInteractionHandler
extends RefCounted
## Evaluators return {} while pending or {grade, option_id, progress, ...} once
## ready. They never route scenes, write Story, own clocks or play animations.

var spec: CADInteractionSpec
var options: Array[CADOption] = []
var progress := 0.0

func configure(value: CADInteractionSpec, offered: Array[CADOption]) -> void:
	spec = value
	options = offered

func input(_sample: CADInputSample) -> Dictionary:
	return {}

func tick(_elapsed: float, _delta: float) -> Dictionary:
	return {}

func prepare_suspend() -> Dictionary:
	return {}

func reset_input() -> void:
	pass

func resume_input(_elapsed: float) -> void:
	pass

func marker(_id: StringName, _at: float) -> bool:
	return false

func timeout() -> Dictionary:
	return {"grade": &"timeout", "progress": progress}

func wrong() -> Dictionary:
	return {"grade": &"miss", "progress": progress} if spec.wrong_input == CADInteractionSpec.WrongInput.FAIL else {}
