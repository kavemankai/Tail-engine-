extends TestSuite
## Checkpoints, resume and rewind.

const EPISODE := preload("res://content/episode_0/episode.tres")

func run() -> void:
	Flow.save_slot = 9
	TESave.erase(9)
	Settings.text_hold_scale = 0.05
	Engine.time_scale = 4.0
	var player := AutoPlayer.new()
	player.options = ["kind", "refuse"]
	player.hotspots = ["Stool", "Bartender", "Stranger"]
	add_child(player)
	Flow.new_game(EPISODE)
	var step: TEStep = await Flow.step_started
	while step.id != &"bar_fight":
		step = await Flow.step_started
	Flow.stop()
	var data := TESave.read(9)
	expect(data["checkpoints"].size() == 3 and data["checkpoints"][2]["title"] == "The fight", "three checkpoints written to the slot")

	# Quit and continue.
	Story.reset()
	expect(Flow.resume(), "resume finds the save")
	step = await Flow.step_started
	expect(step.id == &"bar_fight" and Flow.location.name == &"Bar", "resumed at the newest checkpoint")
	expect(Story.flag(&"bartender_friendly") and Story.flag(&"stool_noticed") and Story.choices[&"stranger"] == &"refuse",
		"story state restored")

	# Rewind to the hub: later choices are undone.
	Flow.rewind(0)
	step = await Flow.step_started
	expect(step.id == &"bar_hub" and not Story.flag(&"bartender_friendly") and Story.choices.is_empty(), "rewind restored the earlier state")
	expect(Flow.checkpoints.size() == 1, "later checkpoints dropped")
	Flow.stop()
	player.free()
	TESave.erase(9)
	expect(not Flow.resume(), "no save, nothing to resume")
	Engine.time_scale = 1.0
	Settings.text_hold_scale = 1.0
	Flow.save_slot = 0
