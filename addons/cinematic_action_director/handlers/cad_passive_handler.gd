class_name CADPassiveHandler
extends CADInteractionHandler
## Deliberate restraint: forbidden presses fail; completing the neutral interval
## yields restrained, including when completion coincides with the deadline.

func input(sample: CADInputSample) -> Dictionary:
	return {"grade": &"miss"} if sample.pressed and sample.action in spec.actions else {}

func tick(elapsed: float, _delta: float) -> Dictionary:
	progress = clampf(elapsed / spec.passive_seconds, 0.0, 1.0)
	if elapsed + 0.0000001 >= spec.passive_seconds:
		return {"grade": &"restrained", "option_id": spec.option_id, "progress": 1.0}
	return {}

func timeout() -> Dictionary:
	return {"grade": &"restrained", "option_id": spec.option_id, "progress": 1.0}
