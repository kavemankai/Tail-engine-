class_name CADInputRouter
extends RefCounted
## Normalises current InputMap bindings. One controller per gate (first matching
## input unless configured); keyboard switching is allowed. Release-to-rearm is
## the default, so a held confirm cannot satisfy a newly acquired challenge.

var controller := -1
var _actions: Array[StringName] = []
var _down: Dictionary = {}
var _blocked: Dictionary = {}
var _sources: Dictionary = {}

func configure(actions: Array[StringName], device: int = -1, carry := false) -> void:
	_actions = actions.duplicate()
	controller = device
	_down.clear()
	_blocked.clear()
	_sources.clear()
	for action in _actions:
		_down[action] = carry and Input.is_action_pressed(action)
		_blocked[action] = not carry and Input.is_action_pressed(action)

func relevant(event: InputEvent) -> bool:
	for action in _actions:
		if event.is_action(action):
			return true
	return false

func route(event: InputEvent, at: float) -> Array[CADInputSample]:
	var samples: Array[CADInputSample] = []
	if event.is_echo():
		return samples
	var pad := event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad and controller >= 0 and event.device != controller:
		return samples
	for action in _actions:
		if not event.is_action(action):
			continue
		var pressed := event.is_action_pressed(action)
		var released := event.is_action_released(action)
		if not pressed and not released:
			continue
		if pad and controller < 0 and pressed:
			controller = event.device
		if _blocked.get(action, false):
			if released and not Input.is_action_pressed(action):
				_blocked[action] = false
				_down[action] = false
			continue
		if bool(_down.get(action, false)) == pressed:
			continue
		var source := _source_id(event)
		if released and _sources.has(action) and _sources[action] != source:
			continue
		_down[action] = pressed
		if pressed:
			_sources[action] = source
		else:
			_sources.erase(action)
		var sample := CADInputSample.new()
		sample.action = action
		sample.pressed = pressed
		sample.strength = event.get_action_strength(action)
		sample.device = event.device if pad else -1
		sample.at = at
		samples.append(sample)
	return samples

func _source_id(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "pad:%d:button:%d" % [event.device, event.button_index]
	if event is InputEventJoypadMotion:
		return "pad:%d:axis:%d" % [event.device, event.axis]
	if event is InputEventKey:
		return "key:%d" % (event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return "action"
