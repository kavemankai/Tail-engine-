extends TestSuite
## History, waiting for the player, recap and credits cards, loading, and
## episode progress.

const SCRIPT_TEXT := "~ start\nAda: Hello [b]there[/b].\nAda: Second line.\n- Stay [#opt=stay]\n\tAda: Good.\n- Leave [#opt=leave]\n\tAda: Fine.\n=> END"

func run() -> void:
	Flow.save_slot = -1
	Settings.reset()
	await history_and_rich_text()
	await waits_for_the_player()
	await cards()
	await loading_and_bad_locations()
	episode_progress()
	await notice_fades()
	Flow.stop()
	await frames(3)
	Settings.reset()
	Flow.save_slot = 0

func card(id: StringName, kind: TEStep.Card, exits: Array[TEExit] = []) -> TEStep:
	var step := TEStep.new()
	step.id = id
	step.kind = TEStep.Kind.CARD
	step.card = kind
	step.heading = "Heading"
	step.body = "Line one\nLine two"
	if exits.is_empty():
		var exit := TEExit.new()
		exit.next = &"END"
		exits = [exit]
	step.exits = exits
	return step

func episode_of(steps: Array[TEStep]) -> TEEpisode:
	var episode := TEEpisode.new()
	episode.id = &"fixture"
	episode.title = "Fixture"
	episode.manifest = TEStoryManifest.new()
	episode.manifest.choices = {&"pick": {&"a": "You picked a."}}
	episode.cast = TECast.new()
	episode.steps = steps
	episode.entry = steps[0].id
	return episode

func history_and_rich_text() -> void:
	Settings.text_hold_scale = 0.75
	Engine.time_scale = 6.0
	var resource := DialogueManager.create_resource_from_text(SCRIPT_TEXT)
	Screen.clear_history()
	var seen := {"balloon": null}
	var on_open := func(balloon: TEBalloon) -> void:
		seen.balloon = balloon
		balloon.choices_shown.connect(func(_line: DialogueLine, _responses: Array) -> void: balloon.pick_option("leave"))
	Flow.balloon_opened.connect(on_open)
	var finished := [false]
	var talk := func() -> void:
		await Flow.converse(resource, "start")
		finished[0] = true
	talk.call()
	await frames(3)
	var balloon: TEBalloon = seen.balloon
	expect(balloon != null and balloon._text.get_parsed_text() == "Hello there.", "subtitle markup is rendered, not shown as tags")
	for i in 600:
		if finished[0]:
			break
		await get_tree().process_frame
	Flow.balloon_opened.disconnect(on_open)
	Engine.time_scale = 1.0
	var lines := Screen.history()
	expect(finished[0] and lines.size() == 4, "every line and the chosen response is recorded")
	expect(lines[0]["speaker"] == "Ada" and lines[2]["speaker"] == "" and lines[2]["text"] == "Leave"
		and lines[3]["text"] == "Fine.", "history keeps speakers, the response taken and what followed, in order")
	Screen.set_paused(true)
	(Screen._pause.find_child("History", true, false) as Button).pressed.emit()
	expect(Screen._history.visible and "Ada: Hello there." in Screen._history_text.get_parsed_text()
		and "> Leave" in Screen._history_text.get_parsed_text(), "the pause menu opens the history")
	expect(get_viewport().gui_get_focus_owner() == Screen._history_back, "history takes focus for controller use")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Screen._input(cancel)
	expect(not Screen._history.visible and Screen._pause.visible and get_tree().paused, "closing history returns to the pause menu")
	Screen.set_paused(false)
	for i in Screen.HISTORY_LIMIT + 20:
		Screen.log_line("A", str(i))
	expect(Screen.history().size() == Screen.HISTORY_LIMIT and Screen.history().back()["text"] == str(Screen.HISTORY_LIMIT + 19),
		"history is bounded and keeps the newest lines")
	Flow.new_game(episode_of([card(&"a", TEStep.Card.TITLE)]))
	expect(Screen.history().is_empty(), "a new game starts with an empty history")
	Flow.stop()
	await frames(2)

func waits_for_the_player() -> void:
	Settings.auto_advance = false
	Settings.text_hold_scale = 0.75
	Engine.time_scale = 8.0
	var resource := DialogueManager.create_resource_from_text("~ start\nAda: One.\nAda: Two.\n=> END")
	var shown: Array[String] = []
	var on_open := func(balloon: TEBalloon) -> void:
		balloon.line_shown.connect(func(line: DialogueLine) -> void: shown.append(line.text))
	Flow.balloon_opened.connect(on_open)
	var finished := [false]
	var talk := func() -> void:
		await Flow.converse(resource, "start")
		finished[0] = true
	talk.call()
	await wait(6.0)
	expect(shown == ["One."] and not finished[0], "with auto-advance off a line waits long past its reading time")
	tap(&"te_advance")
	await frames(4)
	expect(shown == ["One.", "Two."], "advance moves to the next line")
	tap(&"te_advance")
	await frames(4)
	expect(finished[0], "and ends the conversation after the last one")
	Flow.balloon_opened.disconnect(on_open)
	Engine.time_scale = 1.0
	Settings.auto_advance = true

func cards() -> void:
	Settings.text_hold_scale = 2.0
	Flow.new_game(episode_of([card(&"recap", TEStep.Card.RECAP)]))
	await frames(8)
	Story.choose(&"pick", &"a")
	expect(Screen._card.visible and "Continue" in Screen._card_hint.text, "the recap shows how to continue")
	await wait(1.0)
	expect(Flow.running and Screen._card.visible, "the recap stays up for the player to read")
	var ended := [false]
	Flow.episode_finished.connect(func(_exit: StringName) -> void: ended[0] = true, CONNECT_ONE_SHOT)
	tap(&"te_advance")
	for i in 120:
		if ended[0]:
			break
		await get_tree().process_frame
	expect(ended[0], "advance dismisses the recap")

	ended[0] = false
	Flow.episode_finished.connect(func(_exit: StringName) -> void: ended[0] = true, CONNECT_ONE_SHOT)
	Flow.new_game(episode_of([card(&"credits", TEStep.Card.CREDITS)]))
	await frames(8)
	var top := Screen._credits.position.y
	expect(Screen._card.visible and "Line two" in Screen._credits.text and "Skip" in Screen._card_hint.text, "credits roll the step's text")
	await wait(0.5)
	expect(Screen._credits.position.y < top and Flow.running, "the credits move up the screen")
	tap(&"te_advance")
	for i in 120:
		if ended[0]:
			break
		await get_tree().process_frame
	expect(ended[0] and Screen._credits.text == "", "credits can be skipped and clean up")
	Settings.text_hold_scale = 1.0

func loading_and_bad_locations() -> void:
	Screen.loading(0.42)
	expect(Screen._loading.visible and "42%" in Screen._loading.text, "the loading indicator shows progress")
	Screen.loading(-1.0)
	expect(not Screen._loading.visible, "and hides when loading ends")
	var faults := capture_faults()
	for path: String in ["res://no_such_location.tscn", "res://tests/run.tscn"]:
		var step := card(&"a", TEStep.Card.TITLE)
		step.location = path
		var failed := [false]
		Flow.episode_failed.connect(func(_reason: String) -> void: failed[0] = true, CONNECT_ONE_SHOT)
		Flow.new_game(episode_of([step]))
		for i in 240:
			if failed[0]:
				break
			await get_tree().process_frame
		expect(failed[0] and Flow.location == null, "a location that cannot load fails the episode cleanly: " + path)
	expect(faults.size() == 2, "each bad location is reported once")
	release_faults()
	var real := card(&"a", TEStep.Card.TITLE)
	real.location = "res://examples/last_call/episode_0/locations/bar.tscn"
	Flow.new_game(episode_of([real]))
	await Flow.step_started
	expect(Flow.location != null and Flow.location is TELocation and not Screen._loading.visible,
		"a real location loads in the background and the indicator is gone when the step starts")
	Flow.stop()
	await frames(3)

func episode_progress() -> void:
	var season: TESeason = load("res://tests/fixtures/season/season.tres")
	var existed := FileAccess.file_exists(TEProgress.PATH)
	var original := FileAccess.get_file_as_bytes(TEProgress.PATH) if existed else PackedByteArray()
	DirAccess.remove_absolute(TEProgress.PATH)
	expect(TEProgress.reached(season) == 0 and TEProgress.reached(null) == 0, "nothing is unlocked to begin with")
	TEProgress.mark(season, 1)
	expect(TEProgress.reached(season) == 1, "reaching an episode is recorded")
	TEProgress.mark(season, 0)
	expect(TEProgress.reached(season) == 1, "progress never moves backwards")
	TEProgress.mark(season, 99)
	expect(TEProgress.reached(season) == season.episodes.size() - 1, "progress is limited to the episodes that exist")
	DirAccess.remove_absolute(TEProgress.PATH)
	Flow.start_season(season, 1)
	expect(TEProgress.reached(season) == 1, "starting an episode of a season unlocks it")
	Flow.stop()
	DirAccess.remove_absolute(TEProgress.PATH)
	if existed:
		var file := FileAccess.open(TEProgress.PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()

func notice_fades() -> void:
	Screen.notice("Remembered.")
	expect(Screen._notice.modulate.a == 0.0 and Screen._notice.text == "Remembered.", "a notice starts transparent")
	await wait(0.5)
	expect(Screen._notice.modulate.a > 0.9, "and fades in")
