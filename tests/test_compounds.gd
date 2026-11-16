extends TestSuite
## Templates build ordinary CADSequence graphs. Integration tests run the same
## Flow, Story, actors and stages used by Episode 0, with bounded suite watchdogs.

const TEMPLATE := preload("res://content/qte_lab/direction/counter.template.tres")
const EPISODE := preload("res://content/qte_lab/direction/counter_episode.tres")
const VARIANT := preload("res://content/qte_lab/direction/episode_0_directional.tres")

func run() -> void:
	template_contract()
	pose_contract()
	await counter_routes()
	await interruption_contract()
	await episode_variants()
	Flow.stop()
	await frames(3)

func template_contract() -> void:
	var first := TEMPLATE.build()
	var second := TEMPLATE.build()
	expect(first != null and first.validation_errors().is_empty() and first.beats.size() == 6,
		"counterattack template produces a validated six-beat CADSequence")
	expect(TEMPLATE.defence.options[0].next == &"" and first.beats[0].gate != second.beats[0].gate,
		"template builds independent resources without mutating authored gates")
	first.beats[0].gate.options[0].next = &"broken"
	expect(second.validation_errors().is_empty(), "editing one compiled graph cannot affect another")
	expect(second.beats[3].gate.interaction.routes[&"partial"] == &"recover", "authored grade overrides survive compilation")
	var invalid: CADCounterattackTemplate = TEMPLATE.duplicate(true)
	invalid.defence = null
	expect(invalid.build() == null and not invalid.last_errors.is_empty(), "missing template gate is an explicit authoring error")
	invalid = TEMPLATE.duplicate(true)
	invalid.counter.interaction.routes[&"perfect"] = &"nowhere"
	expect(invalid.build() == null and "nowhere" in "\n".join(invalid.last_errors), "compound routes are checked against the compiled graph")
	invalid = TEMPLATE.duplicate(true)
	invalid.counter.interaction.routes[&"miss"] = &"defence"
	expect(invalid.build() == null, "counterattack template rejects cyclic grade overrides and skipped reactions")
	var episode: TEEpisode = EPISODE.duplicate(true)
	episode.find(&"lab").sequence = second
	expect("choose sequence or compound" in "\n".join(TEValidator.check(episode)), "step rejects ambiguous sequence and compound payloads")
	episode = EPISODE.duplicate(true)
	episode.find(&"lab").compound = episode.find(&"lab").compound.duplicate(true)
	episode.find(&"lab").compound.land_timeline = &"missing_clip"
	expect("missing timeline" in "\n".join(TEValidator.check(episode)), "validator checks compiled template against its stage")
	expect(TEValidator.check(EPISODE).is_empty() and TEValidator.check(VARIANT).is_empty(), "authored compound and directional Episode 0 validate")
	var path := "user://counter_template_test_%d.tres" % get_instance_id()
	expect(ResourceSaver.save(TEMPLATE, path) == OK, "compound serialises as a native resource")
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CADCounterattackTemplate
	expect(restored != null and restored.build() != null, "saved compound reloads and compiles")
	DirAccess.remove_absolute(path)

func pose_contract() -> void:
	var library: AnimationLibrary = load("res://content/qte_lab/direction/timelines.tres")
	for role: String in ["Player", "Aggressor"]:
		for pair: Array in [["telegraph", "evade"], ["telegraph", "hit"], ["telegraph", "guard"],
				["evade", "counter_ready"], ["counter_ready", "counter_land"], ["counter_ready", "recover"]]:
			var source := library.get_animation(pair[0])
			var target := library.get_animation(pair[1])
			expect(position_at(source, role, source.length).is_equal_approx(position_at(target, role, 0.0)),
				"%s root continuity: %s -> %s" % [role, pair[0], pair[1]])

func position_at(animation: Animation, role: String, at: float) -> Vector3:
	var track := animation.find_track(NodePath(role + ":position"), Animation.TYPE_VALUE)
	return animation.value_track_interpolate(track, at)

func counter_routes() -> void:
	var trace := await play_counter("left", "perfect")
	expect(trace.outcome == &"countered" and ",".join(trace.beats) == "defence,evade,counter,land", "defence and accurate counter take their authored timelines")
	expect(trace.results == {&"defence": &"dodged", &"counter": &"strike"}, "compound stores independent legacy gate results")
	expect(&"counter" in trace.player_clips and &"hit_react" in trace.npc_clips, "counter timeline dispatches player action and corresponding NPC reaction")
	trace = await play_counter("left", "miss")
	expect(trace.outcome == &"defended" and trace.results[&"defence"] == &"dodged" and trace.results[&"counter"] == &"timeout",
		"missed counter does not retroactively fail the successful dodge")
	trace = await play_counter("left", "partial")
	expect(trace.outcome == &"defended" and trace.counter_grade == &"partial", "partial counter grade follows authored recovery override")
	trace = await play_counter("right", "miss")
	expect(trace.outcome == &"hit" and ",".join(trace.beats) == "defence,hit_reaction", "wrong directional defence takes hit branch without opening counter")

func play_counter(defence: String, counter: String) -> Dictionary:
	Flow.save_slot = -1
	var trace := {"outcome": &"", "beats": [], "results": {}, "player_clips": [], "npc_clips": [], "counter_grade": &""}
	Flow.director_started.connect(func(director: CADDirector) -> void:
		trace.beats.append(director.trail[0])
		director.beat_started.connect(func(beat: CADBeat, _visit: int) -> void: trace.beats.append(beat.id))
		director.gate_opened.connect(func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
			if beat.id == &"defence":
				pulse(&"cad_dir_left" if defence == "left" else &"cad_dir_right")
			elif counter != "miss":
				await get_tree().create_timer(0.4 if counter == "perfect" else 0.62).timeout
				if is_instance_valid(director) and director.active():
					pulse(&"cad_a"))
		director.interaction_resolved.connect(func(result: CADResult) -> void:
			if result.beat_id == &"counter": trace.counter_grade = result.grade)
		director.finished.connect(func(_outcome: StringName) -> void:
			trace.results = director.results.duplicate()
			trace.player_clips = Flow.actors[&"player"].clip_log.duplicate()
			trace.npc_clips = Flow.actors[&"stranger"].clip_log.duplicate()), CONNECT_ONE_SHOT)
	Flow.new_game(EPISODE)
	trace.outcome = await Flow.episode_finished
	Flow.save_slot = 0
	return trace

func interruption_contract() -> void:
	Flow.save_slot = -1
	Flow.new_game(EPISODE)
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	var first_runner := director.interaction_runner
	var outcomes: Array = []
	director.finished.connect(func(outcome: StringName) -> void: outcomes.append(outcome))
	Flow.stop()
	await frames(3)
	expect(first_runner.last_result.grade == &"cancelled" and outcomes == [&"cancelled"]
		and Story.results.is_empty() and Flow.location == null, "interrupting compound cancels once without durable partial results")
	Flow.new_game(EPISODE)
	director = await Flow.director_started
	await director.gate_opened
	pulse(&"cad_dir_left")
	await director.gate_opened
	Flow.stop()
	await frames(3)
	expect(Story.results.is_empty() and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "cancelling at counter releases the whole compound input lease")
	Flow.save_slot = 0

func episode_variants() -> void:
	Flow.save_slot = -1
	Settings.text_hold_scale = 0.05
	Settings.choice_time_scale = 0.2
	Engine.time_scale = 4.0
	var player := await play_variant(["kind", "insult"], ["Stool", "Bartender", "Stranger"],
		{&"rush": "cad_dir_left", &"counter": "cad_a", &"shove": "hold:cad_a"})
	expect(Story.outcome(&"bar_fight") == "won" and Story.result(&"bar_fight", &"counter") == "stool",
		"directional bar variant preserves insult, observation unlock and winning narrative route")
	player.free()
	for fork: StringName in [&"cad_dir_up", &"cad_dir_down"]:
		player = await play_variant(["kind", "refuse"], ["Bartender", "Stranger"],
			{&"windup": "cad_dir_left", &"run1": "cad_a", &"run2": "cad_b", &"run3": fork})
		expect(Story.outcome(&"bar_fight") == "broken_up" and Story.outcome(&"alley_chase") == "escaped"
			and Story.result(&"alley_chase", &"run3") == ("high" if fork == &"cad_dir_up" else "low"),
			"directional chase offers high/low routes while preserving bartender consequence")
		player.free()
	player = await play_variant(["rude", "refuse"], ["Bartender", "Stranger"], {})
	expect(Story.outcome(&"alley_chase") == "was_caught" and "caught_talk" in player.steps, "directional variants retain fail-forward caught dialogue")
	player.free()
	player = await play_variant(["pay"], ["Stranger"], {})
	expect("bar_fight" not in player.steps and "paid_card" in player.steps, "paying still bypasses directional action")
	player.free()
	Engine.time_scale = 1.0
	Settings.text_hold_scale = 1.0
	Settings.choice_time_scale = 1.0
	Flow.save_slot = 0

func play_variant(options: Array, hotspots: Array, gates: Dictionary) -> AutoPlayer:
	var player := AutoPlayer.new()
	player.options = options
	player.hotspots = hotspots
	player.gates = gates
	add_child(player)
	Flow.new_game(VARIANT)
	await Flow.episode_finished
	return player

func pulse(action: StringName) -> void:
	for pressed: bool in [true, false]:
		send(action, pressed)
