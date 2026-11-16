class_name CADPrompt
extends RefCounted
## Connects a Label and a Range to the gate lifecycle. Button names come from
## the InputMap, so remapped actions show the right key or pad button.

const PAD := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}

static func bind(director: CADDirector, label: Label, progress: Range, backdrop: Control = null) -> void:
	var hide_prompt := func() -> void:
		for control: Control in [label, progress, backdrop]:
			if is_instance_valid(control):
				control.hide()
	director.gate_opened.connect(func(_beat: CADBeat, options: Array[CADOption], window: float) -> void:
		var lines := PackedStringArray()
		for option in options:
			lines.append(text_for(option, director.using_pad))
		label.text = "\n".join(lines)
		progress.max_value = window
		progress.value = window
		for control: Control in [label, progress, backdrop]:
			if control != null:
				control.show())
	director.gate_progress.connect(func(remaining: float, hold: float) -> void:
		progress.value = hold * progress.max_value if hold > 0.0 else remaining)
	director.gate_closed.connect(hide_prompt)
	director.finished.connect(func(_outcome: StringName) -> void: hide_prompt.call())
	hide_prompt.call()

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
