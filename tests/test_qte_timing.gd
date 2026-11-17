extends "res://tests/test_interaction.gd"
## Phase 2 policies use the same fixture/clock/router as the phase-1 seam tests.

func run() -> void:
	timing_grades()
	release_contract()
	chord_contract()
	passive_contract()
	marker_contract()
	frame_rates_and_assistance()
	lifecycle_matrix()
	native_input_matrix()
	demo_contract()
	await minimal_rig_contract()

func timing_gate() -> CADGate:
	var value := gate()
	value.interaction.family = CADInteractionSpec.Family.TIMING
	value.interaction.ideal_seconds = 0.75
	value.interaction.perfect_seconds = 0.05
	value.interaction.success_seconds = 0.1
	value.interaction.partial_seconds = 0.2
	for grade: StringName in [&"perfect", &"success", &"partial", &"miss"]:
		value.interaction.routes[grade] = StringName("reaction_" + String(grade))
	return value

func timing_grades() -> void:
	for sample: Array in [[0.75, &"perfect"], [0.70, &"perfect"], [0.80, &"perfect"],
			[0.65, &"success"], [0.85, &"success"], [0.55, &"partial"], [0.95, &"partial"], [0.951, &"miss"]]:
		var value := runner()
		begin(value, timing_gate())
		now[0] = sample[0]
		value.input(edge(), 1, 1)
		expect(value.last_result.grade == sample[1] and value.last_result.route_id == StringName("reaction_" + String(sample[1])),
			"timing boundary %.3f selects %s and its route" % sample)
		expect(is_equal_approx(value.last_result.timing_error_ms, (float(sample[0]) - 0.75) * 1000), "signed timing error is measured in milliseconds")
	var value := runner()
	begin(value, timing_gate())
	now[0] = 0.1
	value.input(edge(), 1, 1)
	expect(value.active, "early timing input follows ignore policy")
	value.input(edge(&"cad_dodge", false), 1, 1)
	now[0] = 0.75
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"perfect", "fresh input after ignored early edge can succeed")
	value = runner()
	var spec := timing_gate()
	spec.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
	begin(value, spec)
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"miss", "wrong mapped timing input follows fail policy")
	value = runner()
	begin(value, spec)
	now[0] = 0.1
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"miss", "early timing input can be authored as failure")
	value = runner()
	begin(value, timing_gate())
	now[0] = 2.0
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"timeout", "late timing input cannot beat deadline")

func release_contract() -> void:
	for sample: Array in [[0.5, &"perfect"], [0.6, &"success"], [0.75, &"partial"], [0.9, &"miss"]]:
		var value := runner()
		var spec := gate(CADInteractionSpec.Gesture.TIMED_RELEASE)
		begin(value, spec)
		value.input(edge(), 1, 1)
		now[0] = sample[0]
		value.input(edge(&"cad_dodge", false), 1, 1)
		expect(value.last_result.grade == sample[1], "timed release at %.2f is %s" % sample)
	var value := runner()
	begin(value, gate(CADInteractionSpec.Gesture.TIMED_RELEASE))
	value.input(edge(&"cad_dodge", false), 1, 1)
	expect(value.active, "unarmed release does not satisfy timed release")
	value.input(edge(), 1, 1)
	now[0] = 0.05
	value.input(edge(&"cad_dodge", false), 1, 1)
	expect(value.active, "too-early release can be ignored")
	value.input(edge(), 1, 1)
	now[0] = 0.5
	value.input(edge(&"cad_dodge", false), 1, 1)
	expect(value.last_result.grade == &"perfect", "release retry needs a fresh press")
	value = runner()
	begin(value, gate(CADInteractionSpec.Gesture.TIMED_RELEASE))
	value.input(edge(), 1, 1)
	now[0] = 2.0
	value.tick()
	expect(value.last_result.grade == &"timeout", "never releasing times out")

func chord_gate() -> CADGate:
	var spec := gate(CADInteractionSpec.Gesture.CHORD)
	spec.interaction.actions = [&"cad_dodge", &"cad_a"]
	return spec

func chord_contract() -> void:
	var value := runner()
	begin(value, chord_gate())
	value.input(edge(), 1, 1)
	value.input(edge(), 1, 1)
	expect(value.active and value.progress() == 0.5, "repeated first chord button is not a second button")
	now[0] = 0.08
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"success", "simultaneous chord accepts exact tolerance boundary")
	value = runner()
	begin(value, chord_gate())
	value.input(edge(), 1, 1)
	now[0] = 0.081
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active, "out-of-tolerance chord does not accidentally succeed")
	value.input(edge(&"cad_a", false), 1, 1)
	value.input(edge(&"cad_dodge", false), 1, 1)
	now[0] = 0.2
	value.input(edge(), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"success", "chord recovers after release and fresh input")
	value = runner()
	var spec := chord_gate()
	spec.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
	begin(value, spec)
	value.input(edge(), 1, 1)
	now[0] = 0.2
	value.tick()
	expect(value.last_result.grade == &"miss", "chord tolerance expiry supports explicit failure policy")
	value = runner()
	begin(value, chord_gate())
	value.input(edge(), 1, 1)
	value.input(edge(&"cad_dodge", false), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active, "chord requires overlapping held buttons")
	value.cancel()

func passive_gate() -> CADGate:
	var spec := gate()
	spec.interaction.family = CADInteractionSpec.Family.PASSIVE
	spec.interaction.passive_seconds = 0.5
	return spec

func passive_contract() -> void:
	var value := runner()
	begin(value, passive_gate())
	now[0] = 0.5
	value.tick()
	expect(value.last_result.grade == &"restrained" and value.last_result.option_id == &"go", "no-input completion is intentional restraint")
	value = runner()
	begin(value, passive_gate())
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active, "passive challenge only forbids its explicit action set")
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"miss", "forbidden press fails no-input challenge")
	Input.action_press(&"cad_dodge")
	value = runner()
	begin(value, passive_gate())
	expect(value.last_result.grade == &"miss", "held forbidden input at acquisition is not mistaken for restraint")
	Input.action_release(&"cad_dodge")
	value = runner()
	var spec := passive_gate()
	spec.interaction.passive_seconds = spec.window_seconds
	begin(value, spec)
	now[0] = 3.0
	value.tick()
	expect(value.last_result.grade == &"restrained", "passive completion at deadline survives a hitch")

func marker_contract() -> void:
	var value := runner()
	var spec := timing_gate()
	spec.interaction.timing_marker = &"anticipation"
	begin(value, spec)
	value.input(edge(), 1, 1)
	expect(value.active, "timing waits for authored marker before grading")
	value.input(edge(&"cad_dodge", false), 1, 1)
	now[0] = 0.2
	expect(not value.marker(&"anticipation", 0, 1) and not value.marker(&"other", 1, 1), "stale or wrong marker cannot anchor timing")
	expect(value.marker(&"anticipation", 1, 1) and not value.marker(&"anticipation", 1, 1), "timing anchor is accepted once per visit")
	now[0] = 0.95
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"perfect", "contact-aligned ideal uses authored marker offset")

func frame_rates_and_assistance() -> void:
	for fps: float in [30.0, 60.0, 120.0]:
		var value := runner()
		begin(value, gate(CADInteractionSpec.Gesture.HOLD))
		value.input(edge(), 1, 1)
		for frame in int(fps):
			now[0] = (frame + 1.0) / fps
			value.tick()
		expect(value.last_result.grade == &"success", "hold is deterministic at %d FPS" % fps)
		value = runner()
		begin(value, timing_gate())
		for frame in int(0.7 * fps):
			now[0] = frame / fps
			value.tick()
		now[0] = 0.75
		value.input(edge(), 1, 1)
		expect(value.last_result.grade == &"perfect", "timing grade is deterministic at %d FPS" % fps)
	var value := runner()
	begin(value, gate(CADInteractionSpec.Gesture.HOLD))
	value.input(edge(), 1, 1)
	now[0] = 5.0
	value.tick()
	expect(value.last_result.grade == &"success", "hold completed before a hitch is not lost to timeout")
	value = runner()
	var spec := timing_gate()
	expect(value.begin(spec, spec.options, 2.0, 1, 1, &"beat"), "timing assist accepts extended window")
	now[0] = 0.9
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"success" and is_equal_approx(value.last_result.timing_error_ms, 150.0),
		"assist widens grades without shifting authored contact instant")

func lifecycle_matrix() -> void:
	var choice := gate()
	choice.interaction.family = CADInteractionSpec.Family.CHOICE
	for spec: CADGate in [gate(), gate(CADInteractionSpec.Gesture.HOLD), gate(CADInteractionSpec.Gesture.TIMED_RELEASE),
			chord_gate(), timing_gate(), passive_gate(), choice]:
		var value := runner()
		begin(value, spec)
		var results: Array = []
		value.resolved.connect(func(result: CADResult) -> void: results.append(result))
		value.suspend(true)
		now[0] = 10.0
		value.input(edge(), 1, 1)
		value.tick()
		expect(value.active and value.clock.elapsed == 0.0, "handler pause blocks input and deadline")
		value.suspend(false)
		value.cancel()
		value.cancel()
		expect(results.size() == 1 and results[0].grade == &"cancelled", "handler cancellation resolves once")
		expect(value.begin(spec, spec.options, 1.0, 2, 2, &"retry"), "handler restarts after cancellation")
		value.input(edge(), 1, 1)
		expect(value.active, "previous visit cannot complete restarted handler")
		value.cancel()
		var director := CADDirector.new()
		director.clock_source = func() -> float: return now[0]
		add_child(director)
		var graph := sequence(spec)
		for destination: StringName in spec.interaction.routes.values():
			if destination not in graph.outcomes:
				graph.outcomes.append(destination)
		expect(director.begin(graph), "handler is usable through shared director")
		var owned := director.interaction_runner
		director.free()
		expect(owned != null and owned.last_result.grade == &"cancelled", "scene unloading cancels handler")

func demo_contract() -> void:
	var lab: GDScript = load("res://examples/last_call/qte_lab/lab.gd")
	var examples: Dictionary = lab.EXAMPLES
	for path: String in examples.values():
		var episode: TEEpisode = lab.episode_for(path)
		expect(episode != null and TEValidator.check(episode).is_empty(), "resource-authored example validates: " + path.get_file())
	var stage: CADStage = preload("res://examples/last_call/episode_0/encounters/bar_fight/stage.tscn").instantiate()
	add_child(stage)
	var invalid: CADSequence = load("res://examples/last_call/qte_lab/parry.tres").duplicate(true)
	invalid.beats[0].gate.interaction.timing_marker = &"missing_contact"
	expect(not stage.validation_errors(invalid).is_empty(), "stage validates authored timing marker references")
	stage.free()

func minimal_rig_contract() -> void:
	var actor: TEActor = load("res://tests/fixtures/tree_actor.gd").new()
	var npc: TEActor = load("res://tests/fixtures/tree_actor.gd").new()
	var character := TECharacter.new()
	character.id = &"fixture"
	character.clips = {&"dodge": &"block"}
	actor.setup(character)
	npc.setup(character)
	add_child(actor)
	add_child(npc)
	var stage: CADStage = preload("res://examples/last_call/episode_0/encounters/bar_fight/stage.tscn").instantiate()
	add_child(stage)
	stage.bind(&"Player", actor)
	stage.bind(&"Aggressor", npc)
	var director := CADDirector.new()
	add_child(director)
	expect(director.begin(load("res://examples/last_call/qte_lab/reaction.tres"), stage), "existing stage accepts AnimationTree actor adapters")
	await frames(3)
	expect(&"windup" in npc.clips, "timeline drives the corresponding NPC animation through cad_act")
	stage.act(&"Player", &"dodge")
	var root_before := actor.global_transform
	actor.tree.advance(0.3)
	# OneShot activation/fade-in and playback are distinct mixer updates.
	actor.tree.advance(0.3)
	expect(actor.clips.back() == &"block" and actor.rig.get_bone_pose_rotation(1).get_angle() > 0.1,
		"logical clip map drives a real skeletal AnimationTree pose")
	expect(actor.global_transform.is_equal_approx(root_before), "skeletal clips do not double-apply timeline root displacement")
	director.cancel()
	await frames(2)
	expect(stage._remotes.is_empty() and actor.global_transform.is_equal_approx(root_before), "release removes timeline ownership and preserves final actor placement")
	director.free()
	stage.free()
	actor.free()
	npc.free()

func native_input_matrix() -> void:
	var choice := gate()
	choice.interaction.family = CADInteractionSpec.Family.CHOICE
	for pad in [false, true]:
		for spec: CADGate in [gate(), gate(CADInteractionSpec.Gesture.HOLD), gate(CADInteractionSpec.Gesture.TIMED_RELEASE),
				chord_gate(), timing_gate(), passive_gate(), choice]:
			var value := runner()
			begin(value, spec)
			# Unrelated device changes update glyph state without changing ownership
			# or completing/penalising a challenge.
			var device := InputEventJoypadMotion.new()
			device.device = 2
			device.axis = JOY_AXIS_RIGHT_X
			device.axis_value = 1.0
			CADInputDevice.observe(device)
			value.input(device, 1, 1)
			var mouse := InputEventMouseButton.new()
			mouse.pressed = true
			CADInputDevice.observe(mouse)
			if spec.interaction.family == CADInteractionSpec.Family.PASSIVE:
				now[0] = 0.5
				value.tick()
			elif spec.interaction.family == CADInteractionSpec.Family.TIMING:
				now[0] = 0.75
				value.input(native_edge(pad, false, true), 1, 1)
			else:
				value.input(native_edge(pad, false, true), 1, 1)
				if spec.interaction.family == CADInteractionSpec.Family.GESTURE:
					match spec.interaction.gesture:
						CADInteractionSpec.Gesture.HOLD:
							now[0] = 0.6
							value.tick()
						CADInteractionSpec.Gesture.TIMED_RELEASE:
							now[0] = 0.5
							value.input(native_edge(pad, false, false), 1, 1)
						CADInteractionSpec.Gesture.CHORD:
							now[0] = 0.04
							value.input(native_edge(pad, true, true), 1, 1)
			expect(value.last_result != null and value.last_result.grade in [&"success", &"perfect", &"restrained"],
				"handler accepts native %s InputMap input across device changes" % ("gamepad" if pad else "keyboard"))

func native_edge(pad: bool, second: bool, pressed: bool) -> InputEvent:
	if pad:
		var value := InputEventJoypadButton.new()
		value.device = 2
		value.button_index = JOY_BUTTON_X if second else JOY_BUTTON_A
		value.pressed = pressed
		return value
	var value := InputEventKey.new()
	value.physical_keycode = KEY_J if second else KEY_SPACE
	value.pressed = pressed
	return value
