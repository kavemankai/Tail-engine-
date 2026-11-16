extends TestSuite
## Complete resource-authored action/dialogue routes plus safe-boundary saves.

const EPISODE := preload("res://examples/last_call/qte_lab/cinematic/episode.tres")
const ENCOUNTER := preload("res://examples/last_call/qte_lab/cinematic/encounter.tres")

func run() -> void:
	var errors := TEValidator.check(EPISODE)
	for problem in errors: print("CINEMATIC VALIDATION ", problem)
	expect(errors.is_empty(), "cinematic action episode validates with native barks and Dialogue Manager cue")
	pose_contract()
	Settings.text_hold_scale = 0.05
	var trace := await play_route("perfect", &"restrain")
	expect(Story.outcome(&"lab") == "restrained" and trace.record.context.momentum == 2, "perfect defence plus observation chooses authored strong follow-through")
	expect(trace.record.results.decision.intent_id == "restrain" and trace.barks == 1, "semantic choice and one action-dialogue cue survive looping slowdown")
	expect(trace.lines == ["Fine. No more fighting."], "completed semantic context hands back to Dialogue Manager after action")
	expect(CADEncounterRecord.valid(Story.interactions[&"lab"]), "Flow commits validated typed history only after successful encounter completion")
	await checkpoint_contract()
	trace = await play_route("perfect", &"leave")
	expect(Story.outcome(&"lab") == "escaped" and Story.intent(&"lab") == "escape", "semantic escape selects its own native timeline")
	expect(trace.lines == ["Go. This ends here."], "Dialogue Manager reads the persistent semantic intent")
	trace = await play_route("miss", &"restrain")
	expect(Story.outcome(&"lab") == "yielded" and trace.record.context.actors.Player == "injured", "failed defence remains recoverable and selects compatible soft choreography")
	trace = await play_route("perfect", &"restrain", false)
	expect(Story.outcome(&"lab") == "yielded" and not trace.record.context.props.bottle, "deleted prop changes adaptive availability instead of choosing impossible follow-through")
	await cancel_contract()
	Settings.text_hold_scale = 1.0
	Flow.save_slot = 0
	Flow.stop()
	await frames(3)

func pose_contract() -> void:
	var library: AnimationLibrary = load("res://examples/last_call/qte_lab/cinematic/timelines.tres")
	for role: String in ["Player", "Aggressor"]:
		for pair in [["threat","block"],["threat","hit"],["block","question"],["hit","question"],["question","assess"],["assess","strong"],["assess","soft"],["assess","escape"]]:
			var first := library.get_animation(pair[0])
			var second := library.get_animation(pair[1])
			var a := first.find_track(NodePath(role+":position"), Animation.TYPE_VALUE)
			var b := second.find_track(NodePath(role+":position"), Animation.TYPE_VALUE)
			expect(first.value_track_interpolate(a, first.length).is_equal_approx(second.value_track_interpolate(b, 0.0)), "%s root continuity %s -> %s" % [role,pair[0],pair[1]])

func play_route(grade: String, choice: StringName, prop_available := true) -> Dictionary:
	Flow.save_slot = -1
	var trace := {"record": {}, "barks": 0, "lines": []}
	Flow.balloon_opened.connect(func(balloon: TEBalloon) -> void:
		balloon.line_shown.connect(func(line: DialogueLine) -> void: trace.lines.append(line.text)), CONNECT_ONE_SHOT)
	Flow.director_started.connect(func(director: CADDirector) -> void:
		var now := [0.0]
		director.clock_source = func() -> float: return now[0]
		for child in director.get_children():
			if child is TEActionDialogue:
				child.line_shown.connect(func(_cue: CADBark) -> void: trace.barks += 1)
		director.gate_opened.connect(func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
			now[0] += (0.4 if grade == "perfect" else 0.8) if beat.id == &"opening" else 0.1
			if beat.id == &"decision" and not prop_available:
				director._stage.target_registry.target(&"bottle").free()
			var event := InputEventAction.new()
			event.action = &"cad_a" if beat.id == &"opening" or choice == &"restrain" else &"cad_b"
			event.pressed = true
			director._input(event)
			event.pressed = false
			director._input(event))
		director.finished.connect(func(_outcome: StringName) -> void: trace.record = director.record()), CONNECT_ONE_SHOT)
	Flow.new_game(EPISODE)
	await Flow.episode_finished
	Flow.save_slot = 0
	return trace

func checkpoint_contract() -> void:
	var checkpoints := Flow.checkpoints.duplicate(true)
	expect(checkpoints.size() == 2 and checkpoints[1].story.interactions.lab.context.intent == "restrain", "checkpoint contains completed semantic consequence rather than live pose")
	expect(TESave.write(89, EPISODE.resource_path, checkpoints), "native cinematic episode writes a compatible checkpoint save")
	Flow.save_slot = 89
	Story.reset()
	expect(Flow.resume(), "cinematic checkpoint resumes through the existing save API")
	var step: TEStep = Flow.step
	expect(step.id == &"checkpoint" and Story.intent(&"lab") == "restrain" and Story.encounter_context(&"lab").momentum == 2, "resume restores semantic intent and completed momentum history")
	Flow.rewind(0)
	var director: CADDirector = await Flow.director_started
	expect(Story.interactions.is_empty() and director.context.momentum == 0 and director.context.intent == &"", "rewind discards later history and creates a fresh encounter context")
	Flow.stop()
	TESave.erase(89)
	Flow.save_slot = 0
	await frames(3)

func cancel_contract() -> void:
	Flow.save_slot = -1
	Flow.new_game(EPISODE)
	var director: CADDirector = await Flow.director_started
	var now := [0.0]
	director.clock_source = func() -> float: return now[0]
	await director.gate_opened
	now[0] = 0.4
	var event := InputEventAction.new()
	event.action = &"cad_a"
	event.pressed = true
	director._input(event)
	event.pressed = false
	director._input(event)
	await director.gate_opened
	var dialogue: TEActionDialogue
	for child in director.get_children():
		if child is TEActionDialogue: dialogue = child
	expect(dialogue.cue != null and director.context.momentum == 2, "cancellation fixture reached live action dialogue and provisional momentum")
	Flow.stop()
	await frames(3)
	expect(Story.interactions.is_empty() and Story.results.is_empty() and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "cancelling during action dialogue commits no provisional consequences or input lease")
