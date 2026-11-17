extends TETitleMenu
## Title screen: the reusable menu pointed at your first episode.

func _init() -> void:
	episode = preload("res://game/episode_1/episode.tres")
	window_title = "{{TITLE}}"
