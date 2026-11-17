extends TETitleMenu
## Last Call's title screen: the reusable menu pointed at Episode 0.

func _init() -> void:
	episode = preload("res://examples/last_call/episode_0/episode.tres")
	window_title = "Tale Engine - Last Call"
	extras = {"Interaction lab": "res://examples/last_call/qte_lab/lab.tscn"}
