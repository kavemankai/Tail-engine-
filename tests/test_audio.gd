extends TestSuite
## Phase 5: bus layout, music and ambience beds, pause ducking, effect pools,
## per-speaker lip-sync, and step audio through Flow.

const TONE_A := preload("res://tests/fixtures/tone_a.wav")
const TONE_B := preload("res://tests/fixtures/tone_b.wav")

func run() -> void:
	buses()
	await beds()
	await ducking()
	effects()
	speakers()
	await steps()

func buses() -> void:
	for bus: StringName in [&"Music", &"SFX", &"Voice", &"Ambience"]:
		expect(AudioServer.get_bus_index(bus) >= 0, "bus %s exists" % bus)
	expect(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Ambience")) == &"SFX",
		"ambience sends to SFX, so the Effects volume covers it")
	expect(String(ProjectSettings.get_setting("audio/buses/default_bus_layout")).ends_with("default_bus_layout.tres"),
		"the project ships a bus layout file")
	var music := AudioServer.get_bus_index(&"Music")
	var duck := false
	for i in AudioServer.get_bus_effect_count(music):
		duck = duck or AudioServer.get_bus_effect(music, i).resource_name == "Duck"
	expect(duck, "the Music bus carries the pause duck")

func beds() -> void:
	Audio.music(TONE_A, 0.1)
	expect(Audio.current_music() == TONE_A and Audio.music_player().playing, "music starts")
	var first := Audio.music_player()
	Audio.music(TONE_A, 0.1)
	expect(Audio.music_player() == first, "asking for the playing track again changes nothing")
	Audio.music(TONE_B, 0.1)
	var second := Audio.music_player()
	expect(second != first and second.stream == TONE_B, "a new track crossfades on the other player")
	await wait(0.3)
	expect(not first.playing and is_equal_approx(second.volume_db, 0.0), "after the crossfade only the new track plays, at full level")
	# A change in the middle of a fade lands cleanly.
	Audio.music(TONE_A, 0.2)
	await wait(0.05)
	Audio.music(TONE_B, 0.1)
	await wait(0.3)
	var playing := 0
	for player: AudioStreamPlayer in [first, second]:
		if player.playing:
			playing += 1
	expect(playing == 1 and Audio.music_player().stream == TONE_B, "interrupting a crossfade leaves one track playing")

	Audio.ambience(TONE_A, 0.0)
	expect(Audio.current_ambience() == TONE_A and Audio.ambience_player().bus == &"Ambience", "ambience plays on its own bus")
	Audio.stop_beds(0.05)
	expect(Audio.current_music() == null and Audio.current_ambience() == null, "stopping clears both beds")
	await wait(0.2)
	expect(not Audio.music_player().playing and not Audio.ambience_player().playing, "and both fade to silence")

func ducking() -> void:
	Audio.music(TONE_A, 0.0)
	get_tree().paused = true
	await wait(0.4)
	expect(is_equal_approx(Audio.duck_db(), Audio.PAUSE_DUCK_DB), "pausing ducks the music")
	expect(Audio.music_player().playing and not Audio.music_player().stream_paused, "music keeps playing under the pause menu")
	get_tree().paused = false
	await wait(0.4)
	expect(is_equal_approx(Audio.duck_db(), 0.0), "resuming brings the music back")
	Audio.music(null, 0.0)

func effects() -> void:
	var players: Array = []
	for i in Audio.POOL_SIZE:
		players.append(Audio.effect(TONE_A))
	var unique := {}
	for player: Node in players:
		unique[player] = true
	expect(unique.size() == Audio.POOL_SIZE and players.all(func(p: AudioStreamPlayer) -> bool: return p.bus == &"SFX"),
		"each overlapping effect gets its own player on the SFX bus")
	var overflow := Audio.effect(TONE_B)
	expect(overflow == players[0] and overflow.stream == TONE_B, "a full pool cuts the oldest effect instead of growing")
	expect(Audio.effects_playing() <= Audio.POOL_SIZE, "the pool is bounded")
	var count := Audio.get_child_count()
	Audio.stop_effects()
	var again := Audio.effect(TONE_A)
	expect(again in players and Audio.get_child_count() == count, "a stopped player is reused, nothing new is created")
	var spatial := Audio.effect_at(TONE_A, Vector3(3, 0, -2))
	expect(spatial is AudioStreamPlayer3D and spatial.global_position.is_equal_approx(Vector3(3, 0, -2)),
		"a positional effect plays where it was asked")
	expect(Audio.effect(null) == null, "a missing stream is ignored")
	Audio.stop_effects()

func speakers() -> void:
	var first := mouth_actor()
	var second := mouth_actor()
	Audio.voice(TONE_A, first)
	expect(Audio.speaking_actor() == first, "a dialogue line drives its speaker's mouth")
	first.set_mouth_open(0.7)
	expect(not Audio.request_voice(TONE_B, self, 50, second), "a bark cannot cut into a dialogue line")
	Audio.stop_voice()
	expect(Audio.speaking_actor() == null and is_zero_approx(mouth_value(first)), "stopping the voice closes the mouth")
	Audio.voice(TONE_A, first)
	first.set_mouth_open(0.7)
	Audio.stop_voice()
	expect(Audio.request_voice(TONE_B, self, 50, second), "a bark plays when the line is over")
	expect(Audio.speaking_actor() == second, "the bark moves its own speaker's mouth, not the last line's")
	Audio.voice(TONE_A, first)
	second.set_mouth_open(0.6)
	Audio.voice(TONE_B, first)
	expect(Audio.speaking_actor() == first, "a new line moves lip-sync to its speaker")
	Audio.stop_voice()
	first.free()
	second.free()
	Audio.voice(TONE_A, null)
	expect(Audio.speaking_actor() == null, "an unvoiced speaker leaves nobody's mouth moving")
	Audio.stop_voice()

func steps() -> void:
	Flow.save_slot = -1
	var opening := card(&"opening", &"middle")
	opening.music = TONE_A
	opening.ambience = TONE_B
	opening.audio_fade = 0.0
	var middle := card(&"middle", &"closing")
	middle.checkpoint = true
	var closing := card(&"closing", Flow.END)
	closing.stop_music = true
	closing.audio_fade = 0.0
	var steps_list: Array[TEStep] = [opening, middle, closing]
	var episode := episode_of(steps_list)
	expect(TEValidator.check(episode).is_empty(), "an episode with step audio validates")

	var started: Array = []
	var on_start := func(step: TEStep) -> void: started.append(step.id)
	Flow.step_started.connect(on_start)
	Flow.new_game(episode)
	await until(func() -> bool: return &"opening" in started)
	expect(Audio.current_music() == TONE_A and Audio.current_ambience() == TONE_B, "a step starts its music and ambience")
	Flow.force_exit(&"end")
	await until(func() -> bool: return &"middle" in started)
	expect(Audio.current_music() == TONE_A, "a step without music keeps what is playing")
	expect(Flow.checkpoints.back().get("audio", {}).get("music", "") == TONE_A.resource_path,
		"a checkpoint remembers the music playing as it was reached")
	Flow.force_exit(&"end")
	await until(func() -> bool: return &"closing" in started)
	expect(Audio.current_music() == null and Audio.current_ambience() == TONE_B, "stop_music fades the music and leaves ambience")
	Flow.rewind(0)
	expect(Audio.current_music() == TONE_A and Audio.current_ambience() == TONE_B, "rewinding to a checkpoint restores its music")
	Flow.stop()
	expect(Audio.current_music() == null and Audio.current_ambience() == null, "stopping the episode fades the beds out")
	Flow.step_started.disconnect(on_start)

	var clash := card(&"clash", Flow.END)
	clash.music = TONE_A
	clash.stop_music = true
	var clash_list: Array[TEStep] = [clash]
	expect(Array(TEValidator.check(episode_of(clash_list))).any(func(e: String) -> bool: return e.contains("both sets and stops the music")),
		"the validator rejects a step that sets and stops music")
	# Let the fade-outs finish so no stream is still playing at shutdown.
	await wait(0.8)
	Flow.save_slot = 0

func until(test: Callable, limit := 3.0) -> void:
	var left := limit
	while not test.call() and left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()

func card(id: StringName, next: StringName) -> TEStep:
	var step := TEStep.new()
	step.id = id
	step.kind = TEStep.Kind.CARD
	step.heading = String(id)
	var exit := TEExit.new()
	exit.on = &"*"
	exit.next = next
	step.exits = [exit]
	return step

func episode_of(steps_list: Array[TEStep]) -> TEEpisode:
	var episode := TEEpisode.new()
	episode.id = &"audio_fixture"
	episode.title = "Audio fixture"
	episode.manifest = TEStoryManifest.new()
	episode.cast = TECast.new()
	var hero := TECharacter.new()
	hero.id = &"hero"
	episode.cast.characters = [hero]
	episode.player = &"hero"
	episode.steps = steps_list
	episode.entry = steps_list[0].id
	return episode

func mouth_actor() -> TEActor:
	var actor := TEActor.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = preload("res://tests/test_voice.gd").blend_shape_mesh("jawOpen")
	actor.add_child(mesh)
	add_child(actor)
	return actor

func mouth_value(actor: TEActor) -> float:
	return (actor.get_child(0) as MeshInstance3D).get_blend_shape_value(0)
