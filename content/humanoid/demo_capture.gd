extends Node
## Automated capture of the actual QTE episode; no synthetic success claim.
var frame_times: Array[float] = []
var last_frame_us := 0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last_frame_us > 0:
		frame_times.append(float(now - last_frame_us) / 1000.0)
	last_frame_us = now

func _ready() -> void:
	Flow.save_slot = -1
	var episode: TEEpisode = load("res://content/episode_0/episode.tres").duplicate(true)
	episode.entry = &"bar_hub"
	Flow.new_game(episode)
	await get_tree().create_timer(1.5).timeout
	Input.action_press(&"move_right")
	await get_tree().create_timer(2.0).timeout
	Input.action_release(&"move_right")
	await get_tree().create_timer(1.0).timeout
	Flow.stop()
	Flow.episode_finished.connect(func(_result: StringName) -> void:
		await get_tree().create_timer(2.0).timeout
		if not frame_times.is_empty():
			frame_times.sort()
			var total := 0.0
			for ms in frame_times: total += ms
			print("FRAME_SAMPLE count=%d mean_ms=%.2f p95_ms=%.2f" % [frame_times.size(), total / frame_times.size(), frame_times[int((frame_times.size() - 1) * 0.95)]])
		get_tree().quit())
	Flow.new_game(load("res://content/qte_lab/direction/counter_episode.tres"))
