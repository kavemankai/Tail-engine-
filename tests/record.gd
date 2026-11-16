extends Node
## Scripted playthrough for recording. Run:
## godot --path . --write-movie out.avi --fixed-fps 30 res://tests/record.tscn

const BAR := preload("res://examples/bar_fight/demo.tscn")
const CHASE := preload("res://examples/alley_chase/demo.tscn")
## Scene, flags, title, then one entry per gate: [action, delay, hold seconds] or null to miss.
const TAKES := [
	[BAR, {&"stool_available": true}, "Bar fight: dodge, grab the stool, hold the shove",
		[[&"cad_dodge", 0.45, 0.0], [&"cad_a", 0.9, 0.0], [&"cad_a", 0.5, 0.8]]],
	[BAR, {}, "Bar fight: missed dodge, no stool in this bar", [null, [&"cad_b", 1.0, 0.0]]],
	[CHASE, {}, "Alley chase: jump, roll, high road", [[&"cad_a", 0.3, 0.0], [&"cad_b", 0.3, 0.0], [&"cad_up", 0.35, 0.0]]],
	[CHASE, {}, "Alley chase: missed jump, then missed roll", [null, null]],
]

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override(&"font_size", 26)
	layer.add_child(title)
	for take: Array in TAKES:
		var demo: Node = take[0].instantiate()
		demo.autostart = false
		demo.flags = take[1]
		add_child(demo)
		title.text = take[2]
		var inputs: Array = take[3].duplicate()
		demo.director.gate_opened.connect(func(_beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
			var step: Variant = inputs.pop_front()
			if step != null:
				_play(step))
		demo.start()
		await demo.director.finished
		await get_tree().create_timer(1.6).timeout
		demo.free()
	get_tree().quit()

func _play(step: Array) -> void:
	await get_tree().create_timer(step[1]).timeout
	_send(step[0], true)
	await get_tree().create_timer(maxf(step[2], 0.05)).timeout
	_send(step[0], false)

func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
