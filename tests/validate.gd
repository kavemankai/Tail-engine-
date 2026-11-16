extends Node
## Prints every problem the validator finds in an episode and exits non-zero
## if there are any. Run: godot --headless --path . res://tests/validate.tscn

const EPISODE := preload("res://content/episode_0/episode.tres")

func _ready() -> void:
	var errors := TEValidator.check(EPISODE)
	for problem in errors:
		print(problem)
	print("%d problem(s). Voice lines: %d of %d." % ([errors.size()] + TEValidator.voice_coverage(EPISODE)))
	get_tree().quit(0 if errors.is_empty() else 1)
