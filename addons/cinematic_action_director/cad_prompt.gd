class_name CADPrompt
extends RefCounted
## Connects a Label and a Range to the gate lifecycle. Button names come from
## the InputMap, so remapped actions show the right key or pad button.

const PAD := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "View", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
}
## Names that differ from PAD for other controller families. Positions are the
## same; only what is printed on the button changes.
const STYLES := {
	&"playstation": {
		JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_START: "Options", JOY_BUTTON_BACK: "Create", JOY_BUTTON_GUIDE: "PS",
	},
	&"nintendo": {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
		JOY_BUTTON_START: "+", JOY_BUTTON_BACK: "-", JOY_BUTTON_GUIDE: "Home",
	},
}
const AXES := {
	JOY_AXIS_LEFT_X: "Left stick", JOY_AXIS_LEFT_Y: "Left stick",
	JOY_AXIS_RIGHT_X: "Right stick", JOY_AXIS_RIGHT_Y: "Right stick",
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
}
const AXIS_STYLES := {
	&"playstation": {JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2"},
	&"nintendo": {JOY_AXIS_TRIGGER_LEFT: "ZL", JOY_AXIS_TRIGGER_RIGHT: "ZR"},
}

## Translate a piece of prompt text. Button letters are never translated.
static func _t(text: String) -> String:
	return String(TranslationServer.translate(text)) if text != "" else ""

## Controls named by a phrase rather than by what is printed on them.
const PHRASES := ["D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right", "Left stick", "Right stick", "Stick"]

## What is printed on a controller button for the controller in use.
static func pad_name(button: int) -> String:
	var names: Dictionary = STYLES.get(CADInputDevice.style(), {})
	var name: String = names.get(button, PAD.get(button, "Pad %d" % button))
	return _t(name) if name in PHRASES else name

static func axis_name(axis: int) -> String:
	var names: Dictionary = AXIS_STYLES.get(CADInputDevice.style(), {})
	var name: String = names.get(axis, AXES.get(axis, "Axis %d" % axis))
	return _t(name) if name in PHRASES else name

## The name of any single input event, for prompts and the rebinding menu.
static func event_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return pad_name(event.button_index)
	if event is InputEventJoypadMotion:
		if event.axis > JOY_AXIS_RIGHT_Y:
			return axis_name(event.axis)
		var name := axis_name(event.axis)
		var arrows := ["←", "→"] if event.axis % 2 == 0 else ["↑", "↓"]
		return "%s %s" % [name, arrows[0] if event.axis_value < 0.0 else arrows[1]]
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	if event is InputEventMouseButton:
		return "Mouse %d" % event.button_index
	return ""

static func bind(director: CADDirector, label: Label, progress: Range, backdrop: Control = null) -> void:
	CADTargetOverlay.install(director)
	var state := {"options": [], "gate": null}
	var refresh := func() -> void:
		var lines := PackedStringArray()
		if state.gate != null and state.gate.interaction != null:
			var forward := director.interaction_runner.direction_forward if director.interaction_runner != null else Vector2.UP
			label.text = interaction_text(state.gate, state.options, director.using_pad, forward, director.interaction_runner.completed_steps() if director.interaction_runner != null else 0)
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
		progress.value = hold * progress.max_value if hold > 0.0 else remaining
		if state.gate != null and state.gate.interaction != null and state.gate.interaction.family == CADInteractionSpec.Family.PATTERN:
			refresh.call())
	director.gate_closed.connect(hide_prompt)
	director.finished.connect(func(_outcome: StringName) -> void: hide_prompt.call())
	director.input_device_changed.connect(refresh)
	hide_prompt.call()

static func interaction_text(gate: CADGate, options: Array, pad: bool, forward := Vector2.UP, completed := 0) -> String:
	var spec := gate.interaction
	if spec.family == CADInteractionSpec.Family.DIRECTION:
		return direction_text(spec, options, pad, forward)
	if spec.family == CADInteractionSpec.Family.TARGET:
		var aim := PackedStringArray()
		for action in spec.direction_actions:
			var control := glyph(action, pad)
			if control not in aim:
				aim.append(control)
		return _t("Aim [%s]\nCycle [%s / %s]\n%s [%s]") % [" / ".join(aim),
			glyph(spec.target_previous_action, pad), glyph(spec.target_next_action, pad),
			_t("Hold to lock") if spec.target_lock_seconds > 0.0 else _t("Select"), glyph(spec.target_confirm_action, pad)]
	if spec.family == CADInteractionSpec.Family.CHOICE:
		return "\n".join(options.map(func(option: CADOption) -> String: return text_for(option, pad)))
	var title := String(spec.id)
	for option: CADOption in options:
		if option.id == spec.option_id:
			title = _t(option.label)
	if spec.family == CADInteractionSpec.Family.PRESSURE:
		return _t("%s\nHold [%s] or [%s]") % [title, glyph(spec.actions[0], pad), glyph(spec.pressure_assist_action, pad)]
	if spec.family == CADInteractionSpec.Family.PATTERN:
		var steps := PackedStringArray()
		var start := maxi(0, completed - 1)
		var end := mini(spec.pattern_steps.size(), start + 4)
		for i in range(start, end):
			steps.append(("✓ " if i < completed else "") + glyph(spec.pattern_steps[i], pad))
		return "%s (%d/%d)\n[%s%s]" % [title, mini(completed + 1, spec.pattern_steps.size()), spec.pattern_steps.size(), " → ".join(steps), " → …" if end < spec.pattern_steps.size() else ""]
	var verb := ""
	if spec.family == CADInteractionSpec.Family.PASSIVE:
		verb = _t("Do not press ")
	elif spec.family == CADInteractionSpec.Family.GESTURE:
		if spec.gesture == CADInteractionSpec.Gesture.HOLD:
			verb = _t("Hold ")
		elif spec.gesture == CADInteractionSpec.Gesture.TIMED_RELEASE:
			verb = _t("Hold, then release ")
	var keys := PackedStringArray()
	for action in spec.actions:
		keys.append(glyph(action, pad))
	return "%s   [%s%s]" % [title, verb, " + ".join(keys)]

static func direction_text(spec: CADInteractionSpec, options: Array, pad: bool, forward: Vector2) -> String:
	var lines := PackedStringArray()
	var pairs: Array = []
	if spec.direction_mode == CADInteractionSpec.DirectionMode.SELECT:
		var sectors := spec.direction_options.keys()
		sectors.sort()
		for sector: int in sectors:
			for option: CADOption in options:
				if option.id == spec.direction_options[sector]:
					pairs.append([option, sector])
	else:
		for option: CADOption in options:
			if option.id == spec.option_id:
				pairs.append([option, int(spec.direction_sector)])
	for pair: Array in pairs:
		var option: CADOption = pair[0]
		var sector: int = pair[1]
		if spec.direction_space == CADInteractionSpec.DirectionSpace.CAMERA:
			sector = CADDirectionHandler.input_sector(sector, forward, spec.direction_eight_way)
		var verb := _t("Hold ") if spec.direction_mode == CADInteractionSpec.DirectionMode.HOLD else ""
		lines.append("%s\n[%s%s]" % [_t(option.label), verb, direction_controls(spec, sector, pad)])
	return "\n".join(lines)

static func direction_controls(spec: CADInteractionSpec, sector: int, pad: bool) -> String:
	var vector := CADDirectionHandler.vector_of(sector)
	var required: Array[int] = []
	if absf(vector.x) > 0.01:
		required.append(0 if vector.x < 0.0 else 1)
	if absf(vector.y) > 0.01:
		required.append(2 if vector.y < 0.0 else 3)
	if not pad:
		var keys := PackedStringArray()
		for i in required:
			var found := ""
			for binding in InputMap.action_get_events(spec.direction_actions[i]):
				if binding is InputEventKey:
					found = OS.get_keycode_string(binding.physical_keycode if binding.physical_keycode != KEY_NONE else binding.keycode)
					break
			if found == "":
				return _t("Unbound")
			keys.append(found)
		return " + ".join(keys)
	var groups: Dictionary = {}
	for i in required:
		for binding in InputMap.action_get_events(spec.direction_actions[i]):
			if spec.controller_device >= 0 and binding.device >= 0 and binding.device != spec.controller_device:
				continue
			var group := ""
			var axis := Vector2.ZERO
			var text := ""
			if binding is InputEventJoypadMotion:
				group = "stick:%d" % int(binding.axis / 2)
				axis = Vector2(signf(binding.axis_value), 0) if binding.axis % 2 == 0 else Vector2(0, signf(binding.axis_value))
			elif binding is InputEventJoypadButton:
				group = "buttons"
				text = pad_name(binding.button_index)
				var dpad := {JOY_BUTTON_DPAD_UP: Vector2.UP, JOY_BUTTON_DPAD_RIGHT: Vector2.RIGHT,
					JOY_BUTTON_DPAD_DOWN: Vector2.DOWN, JOY_BUTTON_DPAD_LEFT: Vector2.LEFT}
				axis = dpad.get(binding.button_index, Vector2.ZERO)
			if group == "":
				continue
			var entry: Dictionary = groups.get(group, {"covered": [], "vector": Vector2.ZERO, "buttons": [], "dpad": true})
			if i not in entry.covered:
				entry.covered.append(i)
				entry.vector += axis
				entry.buttons.append(text)
				if group == "buttons" and axis.is_zero_approx():
					entry.dpad = false
			groups[group] = entry
	var alternatives := PackedStringArray()
	for group: String in groups:
		var entry: Dictionary = groups[group]
		if entry.covered.size() != required.size():
			continue
		var arrow := direction_arrow(CADDirectionHandler.sector_of(entry.vector, true))
		if group.begins_with("stick:"):
			var stick := int(group.get_slice(":", 1))
			alternatives.append("%s %s" % [_t("Left stick") if stick == 0 else (_t("Right stick") if stick == 1 else "Axes %d/%d" % [stick * 2, stick * 2 + 1]), arrow])
		elif entry.dpad:
			alternatives.append(_t("D-pad") + " " + arrow)
		else:
			alternatives.append(" + ".join(entry.buttons))
	return " / ".join(alternatives) if not alternatives.is_empty() else _t("Unbound")

static func direction_arrow(sector: int) -> String:
	return ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"][sector] if sector >= 0 and sector < 8 else "?"

static func text_for(option: CADOption, pad: bool) -> String:
	var verb := _t("Hold ") if option.hold_seconds > 0.0 else ""
	return "%s   [%s%s]" % [_t(option.label), verb, glyph(option.action, pad)]

## The name of the first key or pad button mapped to an action.
## Controller positions -> icon file names in glyphs/<style>/.
const ICON_KEYS := {
	JOY_BUTTON_A: "a", JOY_BUTTON_B: "b", JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_DPAD_UP: "dpad_up", JOY_BUTTON_DPAD_DOWN: "dpad_down",
	JOY_BUTTON_DPAD_LEFT: "dpad_left", JOY_BUTTON_DPAD_RIGHT: "dpad_right",
	JOY_BUTTON_START: "start", JOY_BUTTON_BACK: "back",
	JOY_BUTTON_LEFT_STICK: "ls", JOY_BUTTON_RIGHT_STICK: "rs",
}
const ICON_AXES := {JOY_AXIS_TRIGGER_LEFT: "lt", JOY_AXIS_TRIGGER_RIGHT: "rt"}
## Folder of icon sets, one subfolder per controller style. A game can point
## this at its own licensed set with the same file names.
static var icon_root := "res://addons/cinematic_action_director/glyphs"

## Icon for the controller button bound to `action`, in the style of the
## controller in use, or null when there is none (keyboard, unknown button).
static func icon(action: StringName) -> Texture2D:
	var style := String(CADInputDevice.style())
	if style == "" or not DirAccess.dir_exists_absolute("%s/%s" % [icon_root, style]):
		style = "xbox"
	for event in InputMap.action_get_events(action):
		var key := ""
		if event is InputEventJoypadButton:
			key = ICON_KEYS.get(event.button_index, "")
		elif event is InputEventJoypadMotion:
			key = ICON_AXES.get(event.axis, "")
		var path := "%s/%s/%s.svg" % [icon_root, style, key]
		if key != "" and ResourceLoader.exists(path):
			return load(path)
	return null

static func glyph(action: StringName, pad: bool) -> String:
	var fallback := ""
	for event in InputMap.action_get_events(action):
		var text := ""
		var is_pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
		if event is InputEventJoypadButton:
			text = pad_name(event.button_index)
		elif event is InputEventJoypadMotion:
			# A stick is named without its direction; a trigger by its own name.
			text = axis_name(event.axis) if event.axis > JOY_AXIS_RIGHT_Y else _t("Stick")
		elif event is InputEventKey:
			text = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		if text != "" and is_pad == pad:
			return text
		if fallback == "":
			fallback = text
	return fallback
