class_name CADPressureHandler
extends CADInteractionHandler
## Authored opposed progress, not physics or rapid mashing. Fixed active-time
## integration makes frame hitches deterministic; edges flush fractional steps
## with the old input state before changing force.

const STEP := 0.01
var _held: Dictionary = {}
var _carry := 0.0

func configure(value: CADInteractionSpec, offered: Array[CADOption]) -> void:
	super.configure(value, offered)
	progress = spec.pressure_start

func input(sample: CADInputSample) -> Dictionary:
	var result := _flush()
	if not result.is_empty():
		return result
	if sample.action in [spec.actions[0], spec.pressure_assist_action]:
		_held[sample.action] = sample.pressed
	elif sample.pressed:
		return wrong()
	return {}

func tick(_elapsed: float, delta: float) -> Dictionary:
	_carry += delta
	while _carry >= STEP - 0.0000001:
		_carry = maxf(0.0, _carry - STEP)
		var result := _advance(STEP)
		if not result.is_empty():
			return result
	return {}

func prepare_suspend() -> Dictionary:
	return _flush()

func reset_input() -> void:
	_held.clear()

func timeout() -> Dictionary:
	var result := _flush()
	if not result.is_empty():
		return result
	return {"grade": &"partial" if progress >= spec.pressure_partial - 0.0000001 else &"timeout", "progress": progress}

func _flush() -> Dictionary:
	var fraction := _carry
	_carry = 0.0
	return _advance(fraction) if fraction > 0.0 else {}

func _advance(delta: float) -> Dictionary:
	var resistance := spec.pressure_resistance
	if spec.pressure_curve != null:
		resistance *= clampf(spec.pressure_curve.sample_baked(progress), 0.0, 1.0)
	var force := spec.pressure_gain if _held.values().has(true) else 0.0
	progress = clampf(progress + (force - resistance) * delta, 0.0, 1.0)
	if progress >= 1.0 - 0.0000001:
		progress = 1.0
		return {"grade": &"success", "option_id": spec.option_id, "progress": 1.0}
	if progress <= 0.0000001:
		progress = 0.0
		return {"grade": &"miss", "progress": 0.0}
	return {}
