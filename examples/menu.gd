extends Control

const SCENES := {
	"Bar fight": "res://examples/bar_fight/demo.tscn",
	"Alley chase": "res://examples/alley_chase/demo.tscn",
}

func _ready() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(80, 80)
	add_child(box)
	for title: String in SCENES:
		var button := Button.new()
		button.text = title
		button.pressed.connect(get_tree().change_scene_to_file.bind(SCENES[title]))
		box.add_child(button)
	box.get_child(0).grab_focus.call_deferred()
