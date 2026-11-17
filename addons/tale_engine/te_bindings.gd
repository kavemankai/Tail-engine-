class_name TEBindings
extends RefCounted
## Player rebinding of InputMap actions. Each action has two slots: one for
## keyboard/mouse and one for controller. Only changed slots are saved, so new
## default bindings added by a later version still reach existing players.

## Actions that may be bound to the same button because they are never live at
## the same time. An action in "always" conflicts with every group.
const GROUPS := {
	"always": [&"te_pause"],
	"explore": [&"move_left", &"move_right", &"move_forward", &"move_back", &"te_interact"],
	"dialogue": [&"te_advance", &"te_choice_1", &"te_choice_2", &"te_choice_3", &"te_choice_4"],
	"action": [&"cad_dodge", &"cad_a", &"cad_b", &"cad_up", &"cad_down",
		&"cad_dir_left", &"cad_dir_right", &"cad_dir_up", &"cad_dir_down"],
}
## Display names. Actions not listed here are shown by their id.
const LABELS := {
	&"te_pause": "Pause",
	&"move_left": "Move left", &"move_right": "Move right",
	&"move_forward": "Move forward", &"move_back": "Move back",
	&"te_interact": "Interact", &"te_advance": "Skip line",
	&"te_choice_1": "Response 1", &"te_choice_2": "Response 2",
	&"te_choice_3": "Response 3", &"te_choice_4": "Response 4",
	&"cad_dodge": "Action: dodge", &"cad_a": "Action: strike", &"cad_b": "Action: grab",
	&"cad_up": "Action: high", &"cad_down": "Action: low",
	&"cad_dir_left": "Aim left", &"cad_dir_right": "Aim right",
	&"cad_dir_up": "Aim up", &"cad_dir_down": "Aim down",
}

static var _defaults: Dictionary = {}

## Remember the project's bindings before any player change. Call once at start.
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for action in actions():
		_defaults[action] = InputMap.action_get_events(action).duplicate()

## Every rebindable action that exists in this project, in menu order.
static func actions() -> Array[StringName]:
	var found: Array[StringName] = []
	for group: String in GROUPS:
		for action: StringName in GROUPS[group]:
			if InputMap.has_action(action):
				found.append(action)
	return found

static func label(action: StringName) -> String:
	return LABELS.get(action, String(action))

static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

## True for an event a player could mean as a new binding: a key or button
## going down, or a stick or trigger pushed most of the way.
static func bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventJoypadButton or event is InputEventMouseButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.6
	return false

## The first event of an action for the keyboard/mouse or the controller slot.
static func current(action: StringName, pad: bool) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if is_pad(event) == pad:
			return event
	return null

## Bind `event` to `action`, replacing that action's other events of the same
## device kind. If another action that can be live at the same time already
## used it, the two swap, so nothing is left unbound. Returns that action, or &"".
static func rebind(action: StringName, event: InputEvent) -> StringName:
	var pad := is_pad(event)
	var clean := _normalised(event)
	var previous := current(action, pad)
	var swapped := &""
	for other in _rivals(action):
		for existing in InputMap.action_get_events(other):
			if is_pad(existing) == pad and _same(existing, clean):
				_replace(other, pad, previous)
				swapped = other
	_replace(action, pad, clean)
	return swapped

## Restore the project's bindings.
static func reset() -> void:
	for action: StringName in _defaults:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, event)

## { action: { "pad": bool -> serialised event } } for slots that differ from the defaults.
static func changed_bindings() -> Dictionary:
	var data := {}
	for action: StringName in _defaults:
		for pad: bool in [false, true]:
			var now := current(action, pad)
			var before: InputEvent = null
			for event: InputEvent in _defaults[action]:
				if is_pad(event) == pad:
					before = event
					break
			if now != null and (before == null or not _same(now, before)):
				if not data.has(String(action)):
					data[String(action)] = {}
				data[String(action)]["pad" if pad else "keys"] = _pack(now)
	return data

## Apply saved bindings over the defaults. Unknown actions and malformed
## entries are ignored.
static func restore(data: Variant) -> void:
	reset()
	if data is not Dictionary:
		return
	for key: Variant in data:
		if key is not String or not _defaults.has(StringName(key)) or data[key] is not Dictionary:
			continue
		for slot: String in ["keys", "pad"]:
			var event := _unpack(data[key].get(slot))
			if event != null and is_pad(event) == (slot == "pad"):
				_replace(StringName(key), slot == "pad", event)

## Actions that must not share a button with `action`.
static func _rivals(action: StringName) -> Array[StringName]:
	var rivals: Array[StringName] = []
	var always: Array = GROUPS["always"]
	for group: String in GROUPS:
		var members: Array = GROUPS[group]
		if action in always or group == "always" or action in members:
			for member: StringName in members:
				if member != action and member not in rivals and InputMap.has_action(member):
					rivals.append(member)
	return rivals

static func _replace(action: StringName, pad: bool, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if is_pad(existing) == pad:
			InputMap.action_erase_event(action, existing)
	if event != null:
		InputMap.action_add_event(action, event)

## A binding keeps what identifies the control, not who pressed it or how hard.
static func _normalised(event: InputEvent) -> InputEvent:
	return _unpack(_pack(event))

static func _same(a: InputEvent, b: InputEvent) -> bool:
	return _pack(a) == _pack(b)

static func _pack(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": int(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "index": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"type": "button", "index": int(event.button_index)}
	if event is InputEventJoypadMotion:
		return {"type": "axis", "axis": int(event.axis), "sign": 1 if event.axis_value >= 0.0 else -1}
	return {}

static func _unpack(data: Variant) -> InputEvent:
	if data is not Dictionary:
		return null
	match data.get("type"):
		"key":
			if data.get("code") is int and data["code"] > 0:
				var key := InputEventKey.new()
				key.physical_keycode = data["code"]
				return key
		"mouse":
			if data.get("index") is int and data["index"] > 0:
				var mouse := InputEventMouseButton.new()
				mouse.button_index = data["index"]
				return mouse
		"button":
			if data.get("index") is int and data["index"] >= 0 and data["index"] < JOY_BUTTON_MAX:
				var button := InputEventJoypadButton.new()
				button.device = -1
				button.button_index = data["index"]
				return button
		"axis":
			if data.get("axis") is int and data["axis"] >= 0 and data["axis"] < JOY_AXIS_MAX and data.get("sign") in [1, -1]:
				var motion := InputEventJoypadMotion.new()
				motion.device = -1
				motion.axis = data["axis"]
				motion.axis_value = float(data["sign"])
				return motion
	return null
