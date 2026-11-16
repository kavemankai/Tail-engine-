class_name CADPrompt
extends RefCounted
## Connects a Label and a Range to the gate lifecycle. Button names come from
## the InputMap, so remapped actions show the right key or pad button.

const PAD := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_START: "Start",
}

static func bind(director: CADDirector, label: Label, progress: Range, backdrop: Control = null) -> void:
	var state := {"options": [], "gate": null}
	var refresh := func() -> void:
		var lines := PackedStringArray()
		if state.gate != null and state.gate.interaction != null:
			label.text = interaction_text(state.gate, state.options, director.using_pad)
			return
		for option: CADOption in state.options:
			lines.append(text_for(option, director.using_pad))
		label.text = "\n".join(lines)
	var hide_prompt := func() -> void:
		state.options = []
		state.gate = null
		for control: Control in [label, progress, backdrop]:
			if is_instance_valid(control):
				control.hide()
	director.gate_opened.connect(func(_beat: CADBeat, options: Array[CADOption], window: float) -> void:
		state.options = options
		state.gate = _beat.gate
		refresh.call()
		progress.max_value = window
		progress.value = window
		for control: Control in [label, progress, backdrop]:
			if control != null:
				control.show())
	director.gate_progress.connect(func(remaining: float, hold: float) -> void:
		progress.value = hold * progress.max_value if hold > 0.0 else remaining)
	director.gate_closed.connect(hide_prompt)
	director.finished.connect(func(_outcome: StringName) -> void: hide_prompt.call())
	director.input_device_changed.connect(refresh)
	hide_prompt.call()

static func interaction_text(gate: CADGate, options: Array, pad: bool) -> String:
	var spec := gate.interaction
	if spec.family == CADInteractionSpec.Family.CHOICE:
		return "\n".join(options.map(func(option: CADOption) -> String: return text_for(option, pad)))
	var title := String(spec.id)
	for option: CADOption in options:
		if option.id == spec.option_id:
			title = option.label
	var verb := ""
	if spec.family == CADInteractionSpec.Family.PASSIVE:
		verb = "Do not press "
	elif spec.family == CADInteractionSpec.Family.GESTURE:
		if spec.gesture == CADInteractionSpec.Gesture.HOLD:
			verb = "Hold "
		elif spec.gesture == CADInteractionSpec.Gesture.TIMED_RELEASE:
			verb = "Hold, then release "
	var keys := PackedStringArray()
	for action in spec.actions:
		keys.append(glyph(action, pad))
	return "%s   [%s%s]" % [title, verb, " + ".join(keys)]

static func text_for(option: CADOption, pad: bool) -> String:
	var verb := "Hold " if option.hold_seconds > 0.0 else ""
	return "%s   [%s%s]" % [option.label, verb, glyph(option.action, pad)]

## The name of the first key or pad button mapped to an action.
static func glyph(action: StringName, pad: bool) -> String:
	var fallback := ""
	for event in InputMap.action_get_events(action):
		var text := ""
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if event is InputEventJoypadButton:
			text = PAD.get(event.button_index, "Pad %d" % event.button_index)
		elif event is InputEventJoypadMotion:
			text = "Stick"
		elif event is InputEventKey:
			text = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		if text != "" and is_pad == pad:
			return text
		if fallback == "":
			fallback = text
	return fallback
