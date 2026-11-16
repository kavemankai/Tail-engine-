class_name TestSuite
extends Node3D
## Base for test suites: assertions and input injection.

var failures := 0

func run() -> void:
	pass

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", message)

func send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(action: StringName) -> void:
	send(action, true)
	send(action, false)

func pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func joined(ids: Array) -> String:
	return ",".join(ids)
