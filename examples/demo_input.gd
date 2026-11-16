class_name DemoInput
extends RefCounted
## Input actions for the examples. A real game defines its own in the Input Map.

const ACTIONS := {
	&"cad_dodge": [KEY_SPACE, JOY_BUTTON_A],
	&"cad_a": [KEY_J, JOY_BUTTON_X],
	&"cad_b": [KEY_K, JOY_BUTTON_B],
	&"cad_up": [KEY_W, JOY_BUTTON_DPAD_UP],
	&"cad_down": [KEY_S, JOY_BUTTON_DPAD_DOWN],
	&"demo_replay": [KEY_R, JOY_BUTTON_Y],
	&"demo_menu": [KEY_ESCAPE, JOY_BUTTON_START],
}

static func ensure() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = ACTIONS[action][0]
		InputMap.action_add_event(action, key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = ACTIONS[action][1]
		pad.device = -1
		InputMap.action_add_event(action, pad)
