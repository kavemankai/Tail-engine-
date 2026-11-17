extends TestSuite
## Seasons: carry-over of choices and variables, saves and resume.

func run() -> void:
	Flow.save_slot = -1
	# Long card holds: only force_exit ends an episode, so the test never races a timer.
	Settings.text_hold_scale = 50.0
	Engine.time_scale = 4.0
	await carry_over()
	await save_resume()
	await standalone_unchanged()
	Flow.stop()
	await frames(3)
	Engine.time_scale = 1.0
	Settings.text_hold_scale = 1.0
	Flow.save_slot = 0

func make_season() -> TESeason:
	return load("res://tests/fixtures/season/season.tres")

func finish_episode() -> void:
	await get_tree().create_timer(0.1).timeout
	Flow.force_exit(&"end")
	await Flow.episode_finished

func carry_over() -> void:
	var season := make_season()
	Flow.start_season(season)
	await frames(10)
	Story.put(&"trusted", true)
	Story.put(&"scratch", 3)
	Story.choose(&"gift", &"keep")
	await finish_episode()
	expect(Flow.has_next_episode(), "a season with another episode offers it")
	expect(Flow.next_episode() and Flow.episode.id == &"two", "next_episode starts the second episode")
	await frames(10)
	expect(Story.flag(&"trusted"), "a declared variable carries into the next episode")
	expect(not Story.vars.has(&"scratch"), "a variable the next episode does not declare is dropped")
	expect(Story.prior(&"one", &"gift") == "keep", "earlier choices stay readable")
	expect(Story.choices.is_empty(), "the new episode starts a fresh recap")
	await finish_episode()
	expect(not Flow.has_next_episode() and not Flow.next_episode(), "the last episode ends the season")

func save_resume() -> void:
	Flow.save_slot = 88
	Flow.start_season(make_season())
	await frames(10)
	var data := TESave.read(88)
	expect(not data.is_empty() and data.has("season") and data["season"]["index"] == 0, "season position is saved")
	Flow.stop()
	expect(Flow.resume() and Flow.season != null and Flow.episode.id == &"one", "resume restores the season")
	await frames(5)
	Story.put(&"trusted", true)
	await finish_episode()
	expect(Flow.next_episode(), "a resumed season can advance")
	await frames(10)
	expect(Story.flag(&"trusted"), "carry-over works after a resume")
	Flow.stop()
	TESave.erase(88)
	Flow.save_slot = -1

func standalone_unchanged() -> void:
	Flow.new_game(make_season().episodes[0])
	await frames(5)
	expect(Flow.season == null and not Flow.has_next_episode(), "a standalone episode has no season")
	var data := {"vars": {}, "choices": {}, "outcomes": {}, "results": {}, "seen": {}, "history": {&"a": {&"b": &"c"}}}
	Story.reset(null)
	Story.from_dict(data)
	expect(Story.prior(&"a", &"b") == "c" and Story.to_dict()["history"]["a"]["b"] == "c", "history round-trips through a checkpoint")
