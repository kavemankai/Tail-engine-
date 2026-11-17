extends TestSuite
## Runtime faults stop the episode with a report; they never pass for an ending.
## Also: saves that survive content patches, backups, and season progress.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")
const SLOT := 77

func run() -> void:
	Flow.save_slot = -1
	Settings.text_hold_scale = 50.0
	wildcard_skips_faults()
	undeclared_names_rejected()
	await missing_exit_fails()
	await missing_step_fails()
	await error_exit_can_be_routed()
	repaired_saves()
	backups()
	slot_details()
	await season_progress_survives_restart()
	await disconnect_pauses()
	Flow.stop()
	await frames(3)
	TESave.erase(SLOT)
	Settings.text_hold_scale = 1.0
	Flow.save_slot = 0

func card(id: StringName, exits: Array[TEExit]) -> TEStep:
	var step := TEStep.new()
	step.id = id
	step.kind = TEStep.Kind.CARD
	step.heading = String(id)
	step.exits = exits
	return step

func exit_to(on: StringName, next: StringName) -> TEExit:
	var exit := TEExit.new()
	exit.on = on
	exit.next = next
	return exit

func episode_of(steps: Array[TEStep]) -> TEEpisode:
	var episode := TEEpisode.new()
	episode.id = &"fixture"
	episode.title = "Fixture"
	episode.manifest = TEStoryManifest.new()
	episode.manifest.variables = {&"known": false}
	episode.manifest.choices = {&"pick": {&"a": "You picked a."}}
	episode.cast = TECast.new()
	episode.steps = steps
	episode.entry = steps[0].id
	return episode

func wildcard_skips_faults() -> void:
	var step := card(&"a", [exit_to(&"*", &"b")])
	expect(step.next_for(&"end") == &"b", "wildcard routes an ordinary exit")
	expect(step.next_for(&"error") == &"" and step.next_for(&"cancelled") == &"", "wildcard does not swallow error or cancelled")
	step.exits = [exit_to(&"error", &"fallback"), exit_to(&"*", &"b")]
	expect(step.next_for(&"error") == &"fallback", "an explicit error exit is honoured")

func undeclared_names_rejected() -> void:
	var faults := capture_faults()
	Story.reset(episode_of([card(&"a", [])]).manifest)
	Story.put(&"typo", true)
	Story.choose(&"pick", &"zzz")
	Story.choose(&"nope", &"a")
	expect(faults.size() == 3, "each undeclared name is reported")
	expect(not Story.vars.has(&"typo") and Story.choices.is_empty(), "undeclared values are not stored")
	Story.put(&"known", true)
	Story.choose(&"pick", &"a")
	expect(Story.flag(&"known") and Story.choices[&"pick"] == &"a" and faults.size() == 3, "declared names still work")
	release_faults()

## Plays `episode`, ends its first step with `exit_name`, and reports how it ended.
func play_to_end(episode: TEEpisode, exit_name: StringName) -> Dictionary:
	var seen := {"finished": 0, "failed": 0, "reason": ""}
	var on_finished := func(_exit: StringName) -> void: seen.finished += 1
	var on_failed := func(reason: String) -> void:
		seen.failed += 1
		seen.reason = reason
	Flow.episode_finished.connect(on_finished)
	Flow.episode_failed.connect(on_failed)
	Flow.new_game(episode)
	await frames(10)
	Flow.force_exit(exit_name)
	for i in 240:
		if seen.finished + seen.failed > 0 and not Screen.is_black():
			break
		await get_tree().process_frame
	Flow.episode_finished.disconnect(on_finished)
	Flow.episode_failed.disconnect(on_failed)
	return seen

func missing_exit_fails() -> void:
	var faults := capture_faults()
	var seen: Dictionary = await play_to_end(episode_of([card(&"a", [])]), &"end")
	expect(seen.failed == 1 and seen.finished == 0, "a step with no matching exit fails the episode instead of finishing it")
	expect(faults.size() == 1 and "no exit" in seen.reason, "the fault is reported with its reason")
	expect(Flow.failed and not Flow.running and Flow.location == null, "the flow is stopped and marked failed")
	release_faults()

func missing_step_fails() -> void:
	var faults := capture_faults()
	var seen: Dictionary = await play_to_end(episode_of([card(&"a", [exit_to(&"*", &"nowhere")])]), &"end")
	expect(seen.failed == 1 and seen.finished == 0 and faults.size() == 1, "an exit to a missing step fails the episode")
	# A wildcard used to turn a broken step into a normal continuation.
	seen = await play_to_end(episode_of([card(&"a", [exit_to(&"*", &"END")])]), &"error")
	expect(seen.failed == 1 and seen.finished == 0, "a step ending in error is not routed by a wildcard")
	release_faults()
	seen = await play_to_end(episode_of([card(&"a", [exit_to(&"*", &"END")])]), &"end")
	expect(seen.failed == 0 and seen.finished == 1 and not Flow.failed, "a healthy episode still finishes and clears the failed flag")

func error_exit_can_be_routed() -> void:
	var faults := capture_faults()
	var steps: Array[TEStep] = [card(&"a", [exit_to(&"error", &"END")])]
	var seen: Dictionary = await play_to_end(episode_of(steps), &"error")
	expect(seen.finished == 1 and seen.failed == 0 and faults.is_empty(), "an authored error exit keeps the story going")
	release_faults()

func saved(step: Variant, changes: Callable = Callable()) -> Dictionary:
	Story.reset(EPISODE.manifest)
	Story.put(&"stool_noticed", true)
	var data := {"version": 1, "episode": EPISODE.resource_path,
		"checkpoints": [{"step": step, "title": "The fight", "story": Story.to_dict()}]}
	if changes.is_valid():
		changes.call(data)
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file := FileAccess.open(TESave.path(SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native(data)))
	file.close()
	return TESave.read(SLOT)

func repaired_saves() -> void:
	TESave.erase(SLOT)
	var data := saved(&"bar_fight")
	expect(data.get("version") == 2 and TESave.last_status == TESave.Status.OK, "a version-1 save migrates cleanly")

	data = saved(&"removed_step")
	expect(TESave.last_status == TESave.Status.RECOVERED and data["checkpoints"].size() == 1
		and StringName(data["checkpoints"][0]["step"]) == EPISODE.entry,
		"a save whose only checkpoint was removed restarts the episode instead of vanishing")
	expect(data["checkpoints"][0]["story"]["vars"][&"stool_noticed"] == true, "what the story knew is kept")

	data = saved(&"bar_fight", func(raw: Dictionary) -> void:
		raw.checkpoints.push_front({"step": &"removed_step", "title": "Gone", "story": raw.checkpoints[0].story.duplicate(true)}))
	expect(data["checkpoints"].size() == 1 and StringName(data["checkpoints"][0]["step"]) == &"bar_fight",
		"a removed checkpoint is dropped and the surviving one is used")

	data = saved(&"bar_fight", func(raw: Dictionary) -> void:
		raw.checkpoints[0].story.vars[&"stool_noticed"] = "yes"
		raw.checkpoints[0].story.vars[&"cut_variable"] = 3
		raw.checkpoints[0].story.choices[&"stranger"] = &"cut_option")
	var story: Dictionary = data["checkpoints"][0]["story"]
	expect(TESave.last_status == TESave.Status.RECOVERED and story["vars"][&"stool_noticed"] == false,
		"a variable whose type changed is reset to its default")
	expect(not story["vars"].has(&"cut_variable") and not story["choices"].has(&"stranger"),
		"removed variables and options are dropped")
	expect(TESave.last_notes.size() == 3, "each repair is noted")

	var patched: TEEpisode = EPISODE
	patched.renamed_steps = {&"old_fight": &"bar_fight"}
	patched.manifest.renamed_variables = {&"saw_stool": &"stool_noticed"}
	data = saved(&"old_fight", func(raw: Dictionary) -> void:
		raw.checkpoints[0].story.vars.erase(&"stool_noticed")
		raw.checkpoints[0].story.vars[&"saw_stool"] = true)
	patched.renamed_steps = {}
	patched.manifest.renamed_variables = {}
	expect(StringName(data["checkpoints"][0]["step"]) == &"bar_fight", "a renamed step is followed")
	expect(data["checkpoints"][0]["story"]["vars"].get(&"stool_noticed") == true
		and not data["checkpoints"][0]["story"]["vars"].has(&"saw_stool"), "a renamed variable keeps its value")
	TESave.erase(SLOT)

func backups() -> void:
	TESave.erase(SLOT)
	Story.reset(EPISODE.manifest)
	var checkpoints := [{"step": &"bar_fight", "title": "The fight", "story": Story.to_dict()}]
	expect(TESave.write(SLOT, EPISODE.resource_path, checkpoints) and not FileAccess.file_exists(TESave.backup_path(SLOT)),
		"the first write has nothing to back up")
	checkpoints[0]["title"] = "Second"
	expect(TESave.write(SLOT, EPISODE.resource_path, checkpoints) and FileAccess.file_exists(TESave.backup_path(SLOT)),
		"later writes keep the previous save as a backup")
	var file := FileAccess.open(TESave.path(SLOT), FileAccess.WRITE)
	file.store_string("{ truncated")
	file.close()
	var data := TESave.read(SLOT)
	expect(not data.is_empty() and data["checkpoints"][0]["title"] == "The fight" and TESave.last_status == TESave.Status.RECOVERED,
		"a damaged save falls back to the backup")
	expect(TESave.write(SLOT, EPISODE.resource_path, checkpoints) and TESave.read(SLOT)["checkpoints"][0]["title"] == "Second",
		"saving over a damaged file works and does not replace the good backup with it")
	TESave.erase(SLOT)
	expect(not FileAccess.file_exists(TESave.backup_path(SLOT)), "erasing a slot removes its backup")

	file = FileAccess.open(TESave.path(SLOT), FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native({"version": 99, "episode": EPISODE.resource_path, "checkpoints": []})))
	file.close()
	var before := FileAccess.get_file_as_string(TESave.path(SLOT))
	expect(TESave.read(SLOT).is_empty() and TESave.last_status == TESave.Status.UNREADABLE and TESave.last_error != "",
		"a save from a newer version is reported as unreadable")
	expect(FileAccess.get_file_as_string(TESave.path(SLOT)) == before, "an unreadable save is left untouched")
	TESave.erase(SLOT)
	expect(TESave.read(SLOT).is_empty() and TESave.last_status == TESave.Status.NONE, "an empty slot is not an error")

func slot_details() -> void:
	Story.reset(EPISODE.manifest)
	var checkpoints := [{"step": &"bar_fight", "title": "The fight", "story": Story.to_dict()}]
	TESave.write(SLOT, EPISODE.resource_path, checkpoints, {}, {"playtime": 125.0})
	var info := TESave.info(SLOT)
	expect(info["status"] == TESave.Status.OK and info["checkpoint_title"] == "The fight"
		and info["episode_title"] == EPISODE.title and info["playtime"] == 125.0 and info["saved_at"] > 0
		and info["checkpoints"] == 1, "slot details describe the save")
	Story.vars[&"stray"] = 1
	checkpoints = [{"step": &"bar_fight", "title": "The fight", "story": Story.to_dict()}]
	expect(TESave.write(SLOT, EPISODE.resource_path, checkpoints)
		and not TESave.read(SLOT)["checkpoints"][0]["story"]["vars"].has(&"stray"),
		"a stray value is dropped on write rather than blocking the save")
	TESave.erase(SLOT)
	expect(TESave.info(SLOT)["status"] == TESave.Status.NONE, "an empty slot has no details")

func season_progress_survives_restart() -> void:
	var season: TESeason = load("res://tests/fixtures/season/season.tres")
	Flow.save_slot = SLOT
	TESave.erase(SLOT)
	Flow.start_season(season)
	await frames(10)
	Story.put(&"trusted", true)
	Story.choose(&"gift", &"keep")
	Flow.force_exit(&"end")
	await Flow.episode_finished
	# Close the game here: nothing in memory survives, only the slot.
	Flow.stop()
	Flow.episode = null
	Flow.season = null
	Story.reset()
	var data := TESave.read(SLOT)
	expect(not data.is_empty() and data["season"]["index"] == 1, "finishing an episode moves the save to the next one")
	expect(Flow.resume() and Flow.episode.id == &"two" and Flow.season != null, "Continue after a restart starts the next episode")
	await frames(10)
	expect(Story.flag(&"trusted") and Story.prior(&"one", &"gift") == "keep", "carried state survives the restart")
	Flow.force_exit(&"end")
	await Flow.episode_finished
	expect(TESave.read(SLOT)["season"]["index"] == 1, "finishing the last episode leaves the save where it was")
	Flow.stop()
	TESave.erase(SLOT)
	Flow.save_slot = -1

func disconnect_pauses() -> void:
	Flow.new_game(episode_of([card(&"a", [exit_to(&"*", &"END")])]))
	await frames(10)
	CADInputDevice.set_device(false)
	Screen._on_joy_connection_changed(0, false)
	expect(not get_tree().paused, "unplugging an unused controller does not interrupt keyboard play")
	CADInputDevice.set_device(true)
	Screen._on_joy_connection_changed(0, true)
	expect(not get_tree().paused, "connecting a controller does not pause")
	Screen._on_joy_connection_changed(0, false)
	expect(get_tree().paused and Flow.running, "losing the controller in use pauses the game")
	Screen.set_paused(false)
	CADInputDevice.set_device(false)
	Screen._quit_pressed()
	expect(Flow.running, "quit to menu asks before discarding progress")
	Screen._quit_pressed()
	expect(not Flow.running, "confirming quits to the menu")
	Flow.stop()
	Screen._on_joy_connection_changed(0, false)
	expect(not get_tree().paused, "a disconnect at the menu does not pause")
