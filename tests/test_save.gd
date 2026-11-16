extends TestSuite
## Checkpoints, resume and rewind.

const EPISODE := preload("res://content/episode_0/episode.tres")

func run() -> void:
	invalid_saves()
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

func invalid_saves() -> void:
	Story.reset(EPISODE.manifest)
	var valid := {"version": 1, "episode": EPISODE.resource_path,
		"checkpoints": [{"step": &"bar_fight", "title": "The fight", "story": Story.to_dict()}]}
	for text: String in ["", "{", "null", "[]"]:
		_raw_save(text)
		expect(TESave.read(9).is_empty(), "empty, truncated or non-save JSON rejected: " + text)
	var cases: Array = [{"version": 1}, {"version": 2}]
	for field: String in ["episode", "checkpoints"]:
		var malformed := valid.duplicate(true)
		malformed[field] = 7
		cases.append(malformed)
	for episode_path: String in ["res://missing.tres", "res://content/main.tscn"]:
		var malformed := valid.duplicate(true)
		malformed.episode = episode_path
		cases.append(malformed)
	for checkpoints: Array in [[], [1], [{"step": "bar_fight"}]]:
		var malformed := valid.duplicate(true)
		malformed.checkpoints = checkpoints
		cases.append(malformed)
	for field: String in ["step", "title", "story"]:
		var malformed := valid.duplicate(true)
		malformed.checkpoints[0][field] = 7
		cases.append(malformed)
	for field: String in ["vars", "choices", "outcomes", "results", "seen"]:
		var malformed := valid.duplicate(true)
		malformed.checkpoints[0].story[field] = []
		cases.append(malformed)
	for step_id: String in ["removed_step", "aftermath"]:
		var malformed := valid.duplicate(true)
		malformed.checkpoints[0].step = step_id
		cases.append(malformed)
	var wrong_variable := valid.duplicate(true)
	wrong_variable.checkpoints[0].story.vars[&"stool_noticed"] = "yes"
	cases.append(wrong_variable)
	var wrong_result := valid.duplicate(true)
	wrong_result.checkpoints[0].story.results[&"bar_fight"] = []
	cases.append(wrong_result)
	for malformed: Dictionary in cases:
		_raw_save(JSON.stringify(JSON.from_native(malformed)))
		expect(TESave.read(9).is_empty(), "malformed or incompatible save rejected")
	_raw_save(JSON.stringify(JSON.from_native(valid)))
	expect(not TESave.read(9).is_empty(), "existing version-1 save remains compatible")
	var before := FileAccess.get_file_as_string(TESave.path(9))
	expect(not TESave.write(9, EPISODE.resource_path, []), "invalid write refused")
	var temporary := TESave.path(9) + ".tmp"
	DirAccess.make_dir_absolute(temporary)
	expect(not TESave.write(9, EPISODE.resource_path, valid.checkpoints) and TESave.last_error != "", "failed temporary write is reported")
	expect(FileAccess.get_file_as_string(TESave.path(9)) == before, "failed writes preserve the previous slot")
	DirAccess.remove_absolute(temporary)
	DirAccess.make_dir_absolute(TESave.path(10))
	expect(not TESave.write(10, EPISODE.resource_path, valid.checkpoints), "failed final rename is reported")
	expect(not FileAccess.file_exists(TESave.path(10) + ".tmp"), "failed rename removes temporary file")
	DirAccess.remove_absolute(TESave.path(10))
	TESave.erase(9)

func _raw_save(text: String) -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file := FileAccess.open(TESave.path(9), FileAccess.WRITE)
	file.store_string(text)
	file.close()
