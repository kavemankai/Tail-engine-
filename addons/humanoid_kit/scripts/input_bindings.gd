extends RefCounted
## Install only missing actions so projects can supply their own InputMap.
static func install() -> void:
	_bind(&"hk_left", KEY_A, -1, JOY_AXIS_LEFT_X, -1)
	_bind(&"hk_right", KEY_D, -1, JOY_AXIS_LEFT_X, 1)
	_bind(&"hk_forward", KEY_W, -1, JOY_AXIS_LEFT_Y, -1)
	_bind(&"hk_back", KEY_S, -1, JOY_AXIS_LEFT_Y, 1)
	_bind(&"hk_camera_left", 0, -1, JOY_AXIS_RIGHT_X, -1)
	_bind(&"hk_camera_right", 0, -1, JOY_AXIS_RIGHT_X, 1)
	_bind(&"hk_camera_up", 0, -1, JOY_AXIS_RIGHT_Y, -1)
	_bind(&"hk_camera_down", 0, -1, JOY_AXIS_RIGHT_Y, 1)
	_bind(&"hk_walk", KEY_CTRL, JOY_BUTTON_LEFT_SHOULDER)
	_bind(&"hk_sprint", KEY_SHIFT, JOY_BUTTON_LEFT_STICK)
	_bind(&"hk_jump", KEY_SPACE, JOY_BUTTON_A)
	_bind(&"hk_attack", KEY_F, JOY_BUTTON_X, -1, 1, MOUSE_BUTTON_LEFT)
	_bind(&"hk_melee", KEY_E, JOY_BUTTON_Y)
	_bind(&"hk_roll", KEY_Q, JOY_BUTTON_B)
	_bind(&"hk_aim", KEY_R, -1, JOY_AXIS_TRIGGER_LEFT, 1, MOUSE_BUTTON_RIGHT)
	_bind(&"hk_fire", 0, -1, JOY_AXIS_TRIGGER_RIGHT, 1)
	_bind(&"hk_crouch", KEY_C, JOY_BUTTON_RIGHT_STICK)
	_bind(&"hk_interact", KEY_T, JOY_BUTTON_RIGHT_SHOULDER)

static func _bind(name: StringName, key: int, button: int, axis := -1,
		direction := 1, mouse := 0) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.22)
	if key:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(name, event)
	if button >= 0:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(name, event)
	if axis >= 0:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = direction
		InputMap.action_add_event(name, event)
	if mouse:
		var event := InputEventMouseButton.new()
		event.button_index = mouse
		InputMap.action_add_event(name, event)
