extends "res://tests/test_interaction.gd"

func run() -> void:
	pressure_contract()
	curve_contract()
	pressure_lifecycle_contract()
	pressure_validation_contract()
	await grapple_contract()

func pressure_gate() -> CADGate:
	var value := gate()
	value.window_seconds = 3.0
	value.interaction.family = CADInteractionSpec.Family.PRESSURE
	value.interaction.actions = [&"cad_a"]
	value.interaction.monitored_actions = [&"cad_dodge"]
	value.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
	value.interaction.routes[&"partial"] = &"stagger"
	return value

func advance(value: CADInteractionRunner, to: float, step := 0.01) -> void:
	while now[0] < to - 0.0000001 and value.active:
		now[0] = minf(to, now[0] + step)
		value.tick()

	if value.active and is_equal_approx(now[0], to):
		now[0] = to
		value.tick()

func pressure_contract() -> void:
	for action in [&"cad_a", &"cad_b"]:
		var value := runner()
		begin(value, pressure_gate())
		value.input(edge(action), 1, 1)
		advance(value, 1.2)
		expect(value.last_result.grade == &"success" and value.last_result.progress == 1.0, "sustained primary/alternate hold completes opposed pressure: %s" % action)
	var value := runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	advance(value, 0.5)
	var progress := value.progress()
	value.input(edge(&"cad_a", false), 1, 1)
	advance(value, 0.8)
	expect(value.progress() < progress and value.active, "opposition reduces progress when force stops")
	value.input(edge(&"cad_dodge"), 1, 1)
	expect(value.last_result.grade == &"miss", "incorrect mapped force follows fail policy")
	value = runner()
	begin(value, pressure_gate())
	advance(value, 2.0)
	expect(value.last_result.grade == &"miss" and value.progress() == 0.0, "unopposed resistance reaches authored failure bound")
	value = runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	advance(value, 1.0)
	value.input(edge(&"cad_a", false), 1, 1)
	advance(value, 3.0)
	expect(value.last_result.grade == &"partial" and value.last_result.route_id == &"stagger", "timeout above threshold takes distinct partial branch")
	value = runner()
	begin(value, pressure_gate())
	now[0] = 3.0
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"miss", "late press cannot undo pressure loss before deadline")
	value = runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	expect(is_equal_approx(value.progress(), 0.3), "repeated presses add no instantaneous force or progress")
	now[0] = 5.0
	value.tick()
	expect(value.last_result.grade == &"success", "continuous held force resolves before deadline even across a frame hitch")

func curve_contract() -> void:
	var totals: Array[float] = []
	for step in [1.0/30, 1.0/60, 1.0/120, 0.137]:
		var value := runner()
		var spec := pressure_gate()
		spec.interaction.pressure_curve = Curve.new()
		spec.interaction.pressure_curve.add_point(Vector2(0, 0.2))
		spec.interaction.pressure_curve.add_point(Vector2(1, 1))
		begin(value, spec)
		value.input(edge(&"cad_a"), 1, 1)
		advance(value, 0.7, step)
		totals.append(value.progress())
		value.cancel()
	for total in totals:
		expect(is_equal_approx(total, totals[0]), "fixed-step curve integration agrees across regular and irregular frame deltas")

func pressure_lifecycle_contract() -> void:
	var value := runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	advance(value, 0.4)
	var progress := value.progress()
	value.suspend(true)
	now[0] = 20.0
	value.tick()
	value.input(edge(&"cad_a"), 1, 1)
	expect(is_equal_approx(value.progress(), progress), "pause preserves pressure and rejects paused input")
	value.suspend(false)
	value.input(edge(&"cad_b"), 1, 1)
	advance(value, 21.0)
	expect(value.last_result.grade == &"success", "fresh alternate hold resumes without counting paused wall time")
	Input.action_press(&"cad_a")
	value = runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	advance(value, 0.1)
	expect(value.progress() < 0.3, "preheld force is blocked at gate acquisition")
	Input.action_release(&"cad_a")
	value.input(edge(&"cad_a", false), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	advance(value, 0.2)
	expect(value.progress() > 0.3, "fresh release/press rearms force")
	var count := [0]
	value.resolved.connect(func(_result: CADResult) -> void: count[0] += 1)
	value.cancel()
	value.cancel()
	expect(count[0] == 1 and value.last_result.grade == &"cancelled", "pressure cancellation resolves once")
	now[0] = 0.0
	begin(value, pressure_gate())
	expect(is_equal_approx(value.progress(), 0.3), "restart resets accumulated pressure")
	value.cancel()
	var director := CADDirector.new()
	add_child(director)
	var graph := sequence(pressure_gate())
	graph.outcomes.append(&"stagger")
	director.begin(graph)
	var owned := director.interaction_runner
	director.free()
	expect(owned.last_result.grade == &"cancelled" and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "scene unloading cancels pressure and releases input")
	value = runner()
	begin(value, pressure_gate())
	var pad := InputEventJoypadButton.new()
	pad.device = 2
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	value.input(pad, 1, 1)
	pad.pressed = false
	value.input(pad, 1, 1)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	value.input(key, 1, 1)
	advance(value, 1.2)
	expect(value.last_result.grade == &"success", "native pad/keyboard handoff uses the shared mapped router")

	value = runner()
	begin(value, pressure_gate())
	value.input(edge(&"cad_a"), 1, 1)
	now[0] = 0.005
	value.suspend(true)
	expect(is_equal_approx(value.progress(), 0.303), "pause flushes fractional integration under the old held force")
	value.cancel()

func pressure_validation_contract() -> void:
	for change in ["gain", "nan", "threshold", "opposition", "window", "actions", "assist", "curve"]:
		var value := pressure_gate()
		match change:
			"gain": value.interaction.pressure_gain = 0.0
			"nan": value.interaction.pressure_start = NAN
			"threshold": value.interaction.pressure_partial = 1.1
			"opposition": value.interaction.pressure_resistance = 2.0
			"window": value.window_seconds = 0.2
			"actions": value.interaction.actions = []
			"assist": value.interaction.pressure_assist_action = &"cad_a"
			"curve": value.interaction.pressure_curve = Curve.new()
		expect(not value.interaction.validation_errors(value.options, value.window_seconds).is_empty(), "invalid pressure %s is rejected" % change)

func grapple_contract() -> void:
	var template: CADGrappleTemplate = load("res://examples/last_call/qte_lab/pressure/grapple.tres")
	expect(template.build() != null and template.build().beats.size() == 9, "grapple compiles direction/pressure/release into existing chain graph")
	var invalid: CADGrappleTemplate = template.duplicate(true)
	invalid.gates.remove_at(1)
	expect(invalid.build() == null, "grapple rejects absent opposed-pressure component")
	for name in ["pressure", "grapple"]:
		expect(TEValidator.check(load("res://examples/last_call/qte_lab/pressure/%s_episode.tres" % name)).is_empty(), "pressure example %s validates" % name)
	Flow.save_slot = -1
	Flow.new_game(load("res://examples/last_call/qte_lab/pressure/grapple_episode.tres"))
	var director: CADDirector = await Flow.director_started
	var now_source := [0.0]
	# Gates acquire after the authored anticipation marker, so the injected
	# source applies to every runner without changing real stage playback.
	director.clock_source = func() -> float: return now_source[0]
	director.gate_opened.connect(func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
		var runner := director.interaction_runner
		var event := InputEventAction.new()
		event.action = &"cad_dir_left" if beat.id == &"input_1" else &"cad_a"
		event.pressed = true
		director._input(event)
		now_source[0] += 0.1 if beat.id == &"input_1" else 1.2 if beat.id == &"input_2" else 0.6
		runner.tick()
		event.pressed = false
		director._input(event))
	var clips := {"player": [], "npc": []}
	director.finished.connect(func(_outcome: StringName) -> void:
		clips.player = Flow.actors[&"player"].clip_log.duplicate()
		clips.npc = Flow.actors[&"stranger"].clip_log.duplicate())
	var outcome: StringName = await Flow.episode_finished
	expect(outcome == &"escaped" and Story.results[&"lab"].size() == 3, "grapple inputs complete through shared runners, timelines and compatible story results")
	expect(&"grapple_escape" in clips.player and &"grapple_release" in clips.npc, "escape dispatches player action and paired opponent release")
	Flow.stop()
	await frames(3)
	Flow.new_game(load("res://examples/last_call/qte_lab/pressure/grapple_episode.tres"))
	director = await Flow.director_started
	var failed: StringName = await Flow.episode_finished
	expect(failed == &"caught", "missed grapple direction plays authored failure and terminates safely")
	Flow.stop()
	Flow.save_slot = 0
	await frames(3)
