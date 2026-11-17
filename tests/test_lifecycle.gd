extends TestSuite
## Interrupt real gameplay modes, including their outstanding async waits.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	Flow.save_slot = -1
	Engine.time_scale = 3.0
	Settings.text_hold_scale = 1.0
	await exploration()
	await dialogue()
	await encounter()
	await fades_and_cards()
	await invalid_resume()
	await cancellation_at_handoff()
	Flow.stop()
	await frames(3)
	Engine.time_scale = 1.0
	Flow.save_slot = 0

func enter(step_id: StringName) -> void:
	Flow.new_game(EPISODE)
	Flow.jump(step_id)

func exploration() -> void:
	enter(&"bar_hub")
	var hub: TEHub = await Flow.hub_entered
	var controller := hub._controller
	Screen.set_paused(true)
	await frames(4)
	expect(not controller.can_process(), "pause suspends exploration controller")
	Screen.open_settings()
	Screen.close_settings()
	expect(get_tree().paused, "closing settings preserves an existing pause")
	Screen.set_paused(false)
	Flow.stop()
	await frames(3)
	expect(not is_instance_valid(controller), "quit removes exploration controller")
	clean("exploration")
	enter(&"bar_hub")
	await Flow.hub_entered
	expect(Flow.actors.size() == 3, "restart builds a fresh cast")
	Flow.stop()
	await frames(3)

func dialogue() -> void:
	enter(&"stranger_talk")
	var balloon: TEBalloon = await Flow.balloon_opened
	await balloon.choices_shown
	var remaining := balloon._timer.value
	var voice := AudioStreamWAV.new()
	voice.mix_rate = 8000
	voice.data = PackedByteArray()
	var samples := PackedByteArray()
	samples.resize(8000 * 4)
	voice.data = samples
	Audio.voice(voice)
	Screen.set_paused(true)
	await frames(5)
	expect(balloon.choosing() and balloon._timer.value == remaining, "pause freezes timed dialogue choice")
	expect(not Audio._voice.can_process(), "voice pauses with dialogue")
	Screen.set_paused(false)
	Flow.stop()
	await frames(3)
	expect(not Audio._voice.playing and not is_instance_valid(balloon), "quit cancels conversation and voice")
	clean("dialogue")
	# Rewind while waiting for an answer must release the old conversation.
	enter(&"stranger_talk")
	balloon = await Flow.balloon_opened
	await balloon.choices_shown
	Flow.rewind(0)
	await Flow.balloon_opened
	await frames(3)
	expect(not is_instance_valid(balloon) and Flow.step.id == &"stranger_talk", "rewind replaces a waiting conversation")
	Flow.stop()
	await frames(3)

func encounter() -> void:
	enter(&"bar_fight")
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	var beat_time := director._beat_time
	var outcomes: Array = []
	director.finished.connect(func(outcome: StringName) -> void: outcomes.append(outcome))
	Screen.set_paused(true)
	await frames(5)
	expect(director._beat_time == beat_time, "pause freezes encounter clock and timeline")
	Flow.stop()
	await frames(3)
	expect(outcomes == [&"cancelled"], "encounter cancellation emits exactly one outcome")
	expect(Story.results.is_empty() and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "cancel does not commit results or retain viewport ownership")
	clean("encounter")
	enter(&"bar_fight")
	director = await Flow.director_started
	await director.gate_opened
	Flow.rewind(0)
	await Flow.director_started
	await frames(3)
	expect(not is_instance_valid(director), "rewind releases the previous encounter")
	Flow.stop()
	await frames(3)

func fades_and_cards() -> void:
	enter(&"bar_hub")
	await frames(2)
	Flow.stop()
	await frames(4)
	clean("location fade")
	expect(Screen._fade.color.a == 0.0, "quit during fade restores the menu")
	Flow.new_game(EPISODE)
	await frames(3)
	expect(Screen._card.visible, "title card opened")
	Flow.new_game(EPISODE)
	await frames(3)
	expect(Flow.step.id == &"title" and Screen._card.visible, "restart during card keeps only the new card")
	Flow.stop()
	await frames(3)
	clean("card")

func invalid_resume() -> void:
	enter(&"bar_hub")
	await Flow.hub_entered
	var generation := Flow._generation
	Flow.save_slot = 9
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file := FileAccess.open(TESave.path(9), FileAccess.WRITE)
	file.store_string(JSON.stringify(JSON.from_native({"version": 1})))
	file.close()
	expect(not Flow.resume() and Flow.running and Flow._generation == generation, "invalid Continue leaves the active session intact")
	TESave.erase(9)
	Flow.save_slot = -1
	Flow.stop()
	await frames(3)

func clean(mode: String) -> void:
	expect(not Flow.running and Flow.location == null and Flow.actors.is_empty() and Flow._props.is_empty()
		and Flow._hub == null and not Screen.prompt_backdrop.visible and not Screen._card.visible
		and not get_tree().paused and get_viewport().get_camera_3d() == null,
		"no leftover gameplay state after " + mode)

func cancellation_at_handoff() -> void:
	# Subscribers can stop synchronously in these public announcement signals,
	# before the launched function has reached its first await.
	Flow.hub_entered.connect(func(_hub: TEHub) -> void: Flow.stop(), CONNECT_ONE_SHOT)
	enter(&"bar_hub")
	await wait(0.5)
	clean("synchronous hub handoff cancellation")
	Flow.balloon_opened.connect(func(_balloon: TEBalloon) -> void: Flow.stop(), CONNECT_ONE_SHOT)
	enter(&"stranger_talk")
	await wait(0.5)
	clean("synchronous dialogue handoff cancellation")
	Flow.director_started.connect(func(_director: CADDirector) -> void: Flow.stop(), CONNECT_ONE_SHOT)
	enter(&"bar_fight")
	await wait(0.5)
	clean("synchronous encounter handoff cancellation")
