extends "res://tests/test_interaction.gd"

func run() -> void:
	await bark_contract()
	history_contract()
	await frames(3)

func bark_contract() -> void:
	var stage: CADStage = load("res://examples/last_call/qte_lab/pressure/stage.tscn").instantiate()
	add_child(stage)
	var actor: TEActor = load("res://addons/tale_engine/placeholder_actor.tscn").instantiate()
	var character := TECharacter.new()
	character.id = &"speaker"
	character.display_name = "Speaker"
	actor.setup(character)
	add_child(actor)
	stage.bind(&"Player", actor)
	var cue := CADBark.new()
	cue.id = &"warning"
	cue.speaker = &"Player"
	cue.text = "Let go. We can still end this."
	cue.seconds = 2.0
	stage.barks = [cue]
	var director := CADDirector.new()
	now[0] = 0.0
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	var dialogue := TEActionDialogue.new()
	dialogue.director = director
	dialogue.stage = stage
	director.add_child(dialogue)
	var graph := sequence(gate())
	graph.beats[0].gate.window_seconds = 60.0
	graph.beats[0].timeline = &"ready"
	var shown := [0]
	dialogue.line_shown.connect(func(_cue: CADBark) -> void: shown[0] += 1)
	expect(director.begin(graph, stage), "action dialogue uses the existing encounter input lease")
	expect(stage.bark(&"warning") and not stage.bark(&"warning") and shown[0] == 1, "looping anticipation cannot repeat a bark within one visit")
	cue.text = "changed after acquisition"
	expect(dialogue.cue.text != cue.text and actor._talking, "active bark snapshots text and drives the speaking adapter")
	stage.bark_requested.emit(cue, director._visit - 1)
	expect(shown[0] == 1, "stale timeline dialogue callbacks cannot replace the active subtitle")
	now[0] = 0.5
	dialogue._process(0)
	director.suspend(true)
	now[0] = 20.0
	dialogue._process(0)
	expect(dialogue.cue != null and dialogue.clock.paused, "explicit encounter pause freezes action subtitle time")
	director.suspend(false)
	now[0] = 21.6
	dialogue._process(0)
	expect(dialogue.cue == null and not actor._talking, "resume excludes paused wall time and closes completed subtitle")
	var low := cue.duplicate(true)
	low.priority = 10
	cue.priority = 60
	dialogue.show_bark(cue)
	expect(not dialogue.show_bark(low) and dialogue.cue.priority == 60, "lower-priority action barks do not interrupt the current line")
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 8000
	# AudioStream.data returns a value copy, so assign the sized buffer explicitly.
	var bytes := PackedByteArray()
	bytes.resize(8000)
	wav.data = bytes
	Audio.voice(wav)
	cue.voice = wav
	dialogue.show_bark(cue)
	expect(Audio._voice.playing and Audio._voice_priority == 100 and Audio._voice_owner == null, "action bark cannot preempt legacy Dialogue Manager voice")
	dialogue.close()
	expect(Audio._voice.playing, "closing an unvoiced action subtitle does not stop another voice owner")
	Audio.stop_voice()
	dialogue.show_bark(cue)
	director.suspend(true)
	expect(Audio._voice.stream_paused, "explicit action pause suspends owned voice")
	director.suspend(false)
	expect(not Audio._voice.stream_paused, "action resume restores owned voice playback")
	var stranger := Node.new()
	add_child(stranger)
	Audio.request_voice(wav, stranger, 90)
	dialogue.close()
	expect(Audio._voice.playing and Audio._voice_owner.get_ref() == stranger, "cleanup cannot stop a higher-priority replacement voice")
	Audio.stop_owned_voice(stranger)
	stranger.free()
	var balloon := TEBalloon.new()
	add_child(balloon)
	balloon._responses = [DialogueResponse.new(), DialogueResponse.new()]
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	balloon._input(pad)
	director._input(pad)
	expect(balloon._picked == -1 and director.interaction_runner.last_result.option_id == &"go", "dialogue confirm is evaluated once by the action owner")
	director._process(0)
	expect(dialogue.cue == null, "encounter finish closes action dialogue")
	balloon.free()
	director.begin(graph, stage)
	dialogue.show_bark(cue)
	director.free()
	expect(not Audio._voice.playing and not actor._talking, "scene unloading releases subtitle voice and speaker state")
	stage.free()
	actor.free()
	await frames(3)

func history_contract() -> void:
	var director := CADDirector.new()
	add_child(director)
	var spec := gate()
	spec.interaction.option_intents = {&"go": &"defend"}
	spec.interaction.momentum_changes = {&"success": 2}
	director.begin(sequence(spec))
	director._input(edge())
	director._process(0)
	var record := director.record()
	expect(CADEncounterRecord.valid(record), "completed encounter produces a valid versioned scalar history")
	var episode: TEEpisode = load("res://examples/last_call/episode_0/episode.tres")
	Story.reset(episode.manifest)
	Story.interactions[&"fight"] = record
	var data := Story.to_dict()
	var restored: Dictionary = JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(data))))
	expect(TESave._story(restored) and CADEncounterRecord.valid(restored.interactions.fight), "typed encounter history survives the actual JSON save encoding")
	Story.reset()
	Story.from_dict(restored)
	expect(Story.interaction(&"fight", &"test").intent_id == "defend" and Story.encounter_context(&"fight").momentum == 2,
		"restored history retains semantic decisions and momentum independently of legacy results")
	var snapshot := Story.interaction(&"fight", &"test")
	snapshot.intent_id = "mutated"
	expect(Story.interaction(&"fight", &"test").intent_id == "defend", "Story history readers return isolated snapshots")
	var checkpoints := [{"step": &"bar_fight", "title": "Fight", "story": Story.to_dict()}]
	expect(TESave.write(89, episode.resource_path, checkpoints) and not TESave.read(89).is_empty(), "version-1 save file accepts the optional typed history extension")
	TESave.erase(89)
	data.erase("interactions")
	Story.from_dict(data)
	expect(Story.interactions.is_empty() and TESave._story(data), "old checkpoint restore drops later action history without migrating legacy saves")
	for change in ["schema", "grade", "intent", "progress", "momentum", "key", "run", "props"]:
		var invalid := record.duplicate(true)
		match change:
			"schema": invalid.schema = 2
			"grade": invalid.results.test.grade = "cancelled"
			"intent": invalid.results.test.intent_id = "unknown"
			"progress": invalid.results.test.progress = NAN
			"momentum": invalid.context.momentum = 101
			"key": invalid.results.test.beat_id = "other"
			"run": invalid.results.test.run_id = 1.5
			"props": invalid.context.props = {"bottle": "yes"}
		expect(not CADEncounterRecord.valid(invalid), "malformed typed history %s is rejected" % change)
	director.free()
	Story.reset(episode.manifest)
