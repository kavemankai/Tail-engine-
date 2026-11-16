extends Node
## Run: godot --headless --path . res://validate.tscn

const EPISODE := preload("res://game/episode_1/episode.tres")

func _ready() -> void:
	var errors := TEValidator.check(EPISODE)
	for problem in errors:
		print(problem)
	print("%d problem(s)." % errors.size())
	get_tree().quit(0 if errors.is_empty() else 1)
