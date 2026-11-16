class_name CADDirectionInput
extends RefCounted
## Directional state owned by CADInputRouter. Physical source groups never mix:
## keyboard, each pad's buttons, and each stick pair have separate vectors.
## Raw axis strengths bypass InputMap deadzone rescaling; spec thresholds own
## activation/rearm. An injected held-event snapshot supports deterministic tests.

var _spec: CADInteractionSpec
var _channels: Dictionary = {}
var _blocked: Dictionary = {}
var _owner := ""

func configure(spec: CADInteractionSpec, snapshot: Callable = Callable()) -> void:
	_spec = spec
	_channels.clear()
	_blocked.clear()
	_owner = ""
	var held: Array = snapshot.call() if snapshot.is_valid() else _held_events()
	for event: InputEvent in held:
		if relevant(event):
			_store(event)
	for group: String in _channels:
		if not _neutral(_levels(group)):
			_blocked[group] = true

func relevant(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		for action in _spec.direction_actions:
			for binding in InputMap.action_get_events(action):
				if binding is InputEventJoypadMotion and binding.axis == event.axis \
						and (binding.device < 0 or binding.device == event.device):
					return true
	else:
		for action in _spec.direction_actions:
			if event.is_action(action):
				return true
	return false

func route(event: InputEvent, at: float, controller: int) -> CADInputSample:
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if event.is_echo() or (pad and controller >= 0 and event.device != controller):
		return null
	var group := _store(event)
	var levels := _levels(group)
	var neutral := _neutral(levels)
	if _blocked.get(group, false):
		if neutral:
			_blocked.erase(group)
		return null
	var vector := Vector2(levels[1] - levels[0], levels[3] - levels[2]).limit_length()
	var started := false
	if _owner == "":
		if vector.length() + 0.0000001 < _spec.direction_activation:
			return null
		_owner = group
		started = true
	elif _owner != group:
		# A second source pressed while the first owns the vector must also
		# return to neutral before it can acquire; no held-source handoff.
		if not neutral:
			_blocked[group] = true
		return null
	var sample := CADInputSample.new()
	sample.kind = CADInputSample.Kind.DIRECTION
	sample.vector = vector
	sample.strength = vector.length()
	sample.pressed = not neutral
	sample.started = started
	sample.device = event.device if pad else -1
	sample.at = at
	if neutral:
		_owner = ""
	return sample

func _store(event: InputEvent) -> String:
	var group := _group(event)
	var control := _control(event)
	var levels: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for i in 4:
		var action := _spec.direction_actions[i]
		if event is InputEventJoypadMotion:
			for binding in InputMap.action_get_events(action):
				if binding is InputEventJoypadMotion and binding.axis == event.axis \
						and (binding.device < 0 or binding.device == event.device):
					levels[i] = maxf(levels[i], clampf(event.axis_value * signf(binding.axis_value), 0.0, 1.0))
		elif event.is_action_pressed(action):
			levels[i] = event.get_action_strength(action)
	var controls: Dictionary = _channels.get(group, {})
	if levels.max() > 0.0:
		controls[control] = levels
	else:
		controls.erase(control)
	_channels[group] = controls
	return group

func _levels(group: String) -> Array[float]:
	var levels: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for contribution: Array in _channels.get(group, {}).values():
		for i in 4:
			levels[i] = maxf(levels[i], contribution[i])
	return levels

func _neutral(levels: Array[float]) -> bool:
	# Opposing held controls do not count as neutral just because they cancel.
	return float(levels.max()) <= _spec.direction_rearm + 0.0000001

func _group(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		return "pad:%d:axes:%d" % [event.device, int(event.axis / 2)]
	if event is InputEventJoypadButton:
		return "pad:%d:buttons" % event.device
	if event is InputEventKey:
		return "keyboard"
	if event is InputEventMouseButton:
		return "mouse"
	return "actions:%d" % event.device

func _control(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		return "axis:%d" % event.axis
	if event is InputEventJoypadButton or event is InputEventMouseButton:
		return "button:%d" % event.button_index
	if event is InputEventKey:
		return "key:%d" % (event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	return String(event.action) if event is InputEventAction else "unknown"

func _held_events() -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var seen: Dictionary = {}
	var pads := Input.get_connected_joypads()
	if _spec.controller_device >= 0 and _spec.controller_device not in pads:
		pads.append(_spec.controller_device)
	for action in _spec.direction_actions:
		for binding in InputMap.action_get_events(action):
			if binding is InputEventKey:
				var down := Input.is_physical_key_pressed(binding.physical_keycode) if binding.physical_keycode != KEY_NONE else Input.is_key_pressed(binding.keycode)
				if down:
					var key := binding.duplicate() as InputEventKey
					key.pressed = true
					key.shift_pressed = Input.is_key_pressed(KEY_SHIFT)
					key.ctrl_pressed = Input.is_key_pressed(KEY_CTRL)
					key.alt_pressed = Input.is_key_pressed(KEY_ALT)
					key.meta_pressed = Input.is_key_pressed(KEY_META)
					events.append(key)
			elif binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
				for device: int in pads:
					if (binding.device >= 0 and binding.device != device) or (_spec.controller_device >= 0 and _spec.controller_device != device):
						continue
					var event := binding.duplicate() as InputEvent
					event.device = device
					var down := false
					if event is InputEventJoypadMotion:
						event.axis_value = Input.get_joy_axis(device, event.axis)
						down = not is_zero_approx(event.axis_value)
					else:
						event.pressed = Input.is_joy_button_pressed(device, event.button_index)
						down = event.pressed
					var id := _group(event) + "/" + _control(event)
					if down and not seen.has(id):
						seen[id] = true
						events.append(event)
			elif binding is InputEventMouseButton and Input.is_mouse_button_pressed(binding.button_index):
				var event := binding.duplicate() as InputEventMouseButton
				event.pressed = true
				events.append(event)
		# Synthetic InputEventAction state has no physical device to query.
		if Input.get_action_raw_strength(action) > 0.0:
			var physical := false
			for event in events:
				if event.is_action_pressed(action):
					physical = true
			if not physical:
				var event := InputEventAction.new()
				event.action = action
				event.pressed = true
				event.strength = Input.get_action_raw_strength(action)
				events.append(event)
	return events
