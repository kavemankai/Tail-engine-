extends Node
## Scripted playthroughs for recording. Run under a display:
## godot --path . --write-movie out.avi --fixed-fps 30 res://tests/record.tscn

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")
## Dialogue options, hotspots to visit, gate inputs.
const ROUTES := [
	[["kind", "insult"], ["Stool", "Bartender", "Stranger"], {&"rush": "cad_dodge", &"counter": "cad_a", &"shove": "hold:cad_a"}],
	[["rude", "refuse"], ["Bartender", "Stranger"], {&"run1": "cad_a"}],
]

func _ready() -> void:
	Flow.save_slot = -1
	for route: Array in ROUTES:
		var player := AutoPlayer.new()
		player.options = route[0]
		player.hotspots = route[1]
		player.gates = route[2]
		player.delay = 0.45
		add_child(player)
		Flow.new_game(EPISODE)
		await Flow.episode_finished
		player.free()
	get_tree().quit()
