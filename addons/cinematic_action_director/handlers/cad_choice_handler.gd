class_name CADChoiceHandler
extends CADInteractionHandler

func input(sample: CADInputSample) -> Dictionary:
	if sample.pressed:
		for option in options:
			if option.action == sample.action:
				return {"grade": &"success", "option_id": option.id, "progress": 1.0}
	return {}
