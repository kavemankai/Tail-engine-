extends TestSuite
## Deterministic interaction contract tests; no frame-count timing assumptions.

var now := [0.0]

func run() -> void:
	clock_contract()
	press_contract()
	hold_contract()
	choice_contract()
	router_contract()
	remapping_contract()
	validation_contract()
	director_contract()
	focus_contract()
	await lab_contract()

func runner() -> CADInteractionRunner:
	now[0] = 0.0
	return CADInteractionRunner.new(func() -> float: return now[0])

func gate(mode: CADInteractionSpec.Gesture = CADInteractionSpec.Gesture.PRESS) -> CADGate:
	var option := CADOption.new()
	option.id = &"go"
	option.action = &"cad_dodge"
	option.next = &"won"
	var value := CADGate.new()
	value.options = [option]
	value.window_seconds = 2.0
	value.timeout_next = &"lost"
	value.interaction = CADInteractionSpec.new()
	value.interaction.id = &"test"
	value.interaction.option_id = &"go"
	value.interaction.actions = [&"cad_dodge"]
	value.interaction.gesture = mode
	value.interaction.monitored_actions = [&"cad_a"]
	return value

func edge(action: StringName = &"cad_dodge", pressed := true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event

func begin(value: CADInteractionRunner, spec: CADGate) -> void:
	expect(value.begin(spec, spec.options, 1.0, 1, 1, &"beat"), "runner accepts valid interaction")

func clock_contract() -> void:
	var clock := CADClock.new(func() -> float: return now[0])
	now[0] = 0.3
	expect(is_equal_approx(clock.tick(), 0.3), "clock uses injected monotonic seconds")
	clock.set_paused(true)
	now[0] = 10.0
	clock.set_paused(false)
	expect(is_equal_approx(clock.elapsed, 0.3), "pause excludes wall time")
	now[0] = 9.0
	expect(is_equal_approx(clock.tick(), 0.3), "backward source samples cannot rewind the clock")

func press_contract() -> void:
	var value := runner()
	var spec := gate()
	begin(value, spec)
	var resolved: Array = []
	value.resolved.connect(func(result: CADResult) -> void: resolved.append(result))
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active, "unwanted mapped input is ignored by authored default")
	value.input(edge(), 0, 1)
	value.input(edge(), 1, 0)
	expect(value.active, "stale run and visit input is rejected")
	now[0] = 0.25
	value.input(edge(), 1, 1)
	value.input(edge(), 1, 1)
	value.cancel()
	expect(resolved.size() == 1 and value.last_result.grade == &"success", "press resolves exactly once")
	expect(value.last_result.option_id == &"go" and value.last_result.route_id == &"won"
		and value.last_result.beat_id == &"beat", "typed result separates option, grade and graph route")
	var serialised := value.last_result.to_dict()
	expect(serialised.run_id == 1 and serialised.visit_id == 1 and serialised.grade is String, "result dump contains stable scalar identity")
	value = runner()
	begin(value, gate())
	now[0] = 2.0
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"timeout", "deadline tie favours timeout")
	value = runner()
	begin(value, gate())
	now[0] = 9.0
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"timeout", "frame hitch cannot admit late input")
	value = runner()
	spec = gate()
	spec.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
	spec.interaction.routes[&"miss"] = &"recover"
	begin(value, spec)
	spec.interaction.routes[&"miss"] = &"changed_after_begin"
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"miss" and value.last_result.route_id == &"recover", "wrong-input route uses immutable acquired spec")
	value = runner()
	begin(value, gate())
	value.cancel()
	value.cancel()
	expect(value.last_result.grade == &"cancelled" and value.last_result.route_id == &"", "cancellation has no authored story route")
	begin(value, gate())
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"success", "runner restarts with cleared state")

func hold_contract() -> void:
	var value := runner()
	begin(value, gate(CADInteractionSpec.Gesture.HOLD))
	value.input(edge(), 1, 1)
	now[0] = 0.2
	value.input(edge(&"cad_dodge", false), 1, 1)
	now[0] = 0.8
	value.tick()
	expect(value.active and value.progress() == 0.0, "tap does not satisfy hold")
	value.input(edge(), 1, 1)
	now[0] = 1.1
	value.tick()
	expect(value.progress() > 0.5 and value.active, "hold reports bounded progress")
	value.suspend(true)
	now[0] = 20.0
	value.tick()
	expect(value.active and value.clock.paused, "pause cannot time out or complete hold")
	value.suspend(false)
	value.input(edge(&"cad_dodge", false), 1, 1)
	value.input(edge(), 1, 1)
	now[0] = 20.6
	value.tick()
	expect(value.last_result.grade == &"success", "fresh hold after pause can complete")

func choice_contract() -> void:
	var value := runner()
	var spec := gate()
	spec.interaction.family = CADInteractionSpec.Family.CHOICE
	var second := CADOption.new()
	second.id = &"leave"
	second.action = &"cad_b"
	second.next = &"left"
	spec.options.append(second)
	begin(value, spec)
	value.input(edge(&"cad_b"), 1, 1)
	expect(value.last_result.option_id == &"leave" and value.last_result.route_id == &"left", "choice uses stable authored option id")
	value = runner()
	begin(value, spec)
	now[0] = 2.1
	value.tick()
	expect(value.last_result.grade == &"timeout" and value.last_result.option_id == &"", "missing choice is distinct from a default selection")

func router_contract() -> void:
	Input.action_press(&"cad_dodge")
	var value := runner()
	begin(value, gate())
	value.input(edge(), 1, 1)
	expect(value.active, "held confirm at acquisition cannot complete new gate")
	Input.action_release(&"cad_dodge")
	value.input(edge(&"cad_dodge", false), 1, 1)
	value.input(edge(), 1, 1)
	expect(value.last_result.grade == &"success", "release rearms the action")
	var router := CADInputRouter.new()
	router.configure([&"cad_dodge"])
	var first := InputEventJoypadButton.new()
	first.device = 2
	first.button_index = JOY_BUTTON_A
	first.pressed = true
	expect(router.route(first, 0.0).size() == 1 and router.controller == 2, "first controller acquires gate input")
	var other := first.duplicate() as InputEventJoypadButton
	other.device = 3
	other.pressed = false
	expect(router.route(other, 0.0).is_empty(), "second controller cannot release first controller input")
	expect(router.route(first, 0.0).is_empty(), "repeated press is debounced")
	var unrelated_release := InputEventKey.new()
	unrelated_release.physical_keycode = KEY_SPACE
	unrelated_release.pressed = false
	expect(router.route(unrelated_release, 0.0).is_empty(), "keyboard release cannot release a latched pad action")
	var release := first.duplicate() as InputEventJoypadButton
	release.pressed = false
	expect(router.route(release, 0.0).size() == 1, "owned controller release is delivered")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	key.echo = true
	expect(router.route(key, 0.0).is_empty(), "keyboard echo cannot complete an interaction")

func validation_contract() -> void:
	var spec := gate()
	expect(spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "valid spec passes validation")
	spec.interaction.actions = [&"missing_action"]
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "missing logical action is rejected")
	spec.interaction.actions = [&"cad_dodge"]
	spec.interaction.routes[&"unknown_grade"] = &"won"
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "unknown result grade is rejected")

func remapping_contract() -> void:
	var original := InputMap.action_get_events(&"cad_dodge")
	InputMap.action_erase_events(&"cad_dodge")
	var binding := InputEventKey.new()
	binding.physical_keycode = KEY_F9
	InputMap.action_add_event(&"cad_dodge", binding)
	var value := runner()
	begin(value, gate())
	var old_key := InputEventKey.new()
	old_key.physical_keycode = KEY_SPACE
	old_key.pressed = true
	value.input(old_key, 1, 1)
	expect(value.active, "removed binding cannot complete interaction")
	var new_key := binding.duplicate() as InputEventKey
	new_key.pressed = true
	value.input(new_key, 1, 1)
	expect(value.last_result != null and value.last_result.grade == &"success", "router resolves current remapped InputMap action")
	InputMap.action_erase_events(&"cad_dodge")
	for event in original:
		InputMap.action_add_event(&"cad_dodge", event)

func focus_contract() -> void:
	var balloon := TEBalloon.new()
	add_child(balloon)
	balloon._responses = [DialogueResponse.new(), DialogueResponse.new(), DialogueResponse.new()]
	var director := CADDirector.new()
	add_child(director)
	director.begin(sequence(gate()))
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	balloon._input(event)
	director._input(event)
	expect(balloon._picked == -1 and director.results.get(&"test") == &"go", "shared gamepad confirm is consumed by action owner only")
	director.free()
	balloon.free()

func sequence(spec: CADGate) -> CADSequence:
	var beat := CADBeat.new()
	beat.id = &"test"
	beat.gate = spec
	var value := CADSequence.new()
	value.entry = beat.id
	value.beats = [beat]
	value.outcomes = [&"won", &"lost"]
	return value

func director_contract() -> void:
	var director := CADDirector.new()
	var outcomes: Array = []
	var details: Array = []
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	director.finished.connect(func(outcome: StringName) -> void: outcomes.append(outcome))
	director.interaction_resolved.connect(func(result: CADResult) -> void: details.append(result))
	now[0] = 0.0
	expect(director.begin(sequence(gate())), "director starts opt-in interaction")
	director._input(edge())
	director._process(0.0)
	expect(outcomes == [&"won"] and details.size() == 1 and director.results[&"test"] == &"go",
		"typed gate routes through existing graph and preserves legacy result")
	var previous: CADResult = details[0]
	expect(director.detailed_results[&"test"].grade == &"success", "director exposes additive typed detail")
	now[0] = 0.0
	director.begin(sequence(gate(CADInteractionSpec.Gesture.HOLD)))
	director._on_interaction_resolved(previous)
	expect(director.results.is_empty(), "stale typed callback from previous run cannot route")
	Engine.time_scale = 0.1
	director._input(edge())
	now[0] = 0.6
	director._process(0.001)
	expect(outcomes == [&"won", &"won"], "interaction seconds are independent of Engine.time_scale")
	Engine.time_scale = 1.0
	now[0] = 0.0
	director.begin(sequence(gate()))
	get_tree().paused = true
	now[0] = 30.0
	director._process(0.0)
	expect(director.interaction_runner.clock.elapsed == 0.0, "scene-tree pause suspends real-time interaction clock")
	get_tree().paused = false
	director._input(edge())
	director._process(0.0)
	expect(outcomes.back() == &"won", "scene-tree resume excludes paused wall time")
	now[0] = 0.0
	director.begin(sequence(gate(CADInteractionSpec.Gesture.HOLD)))
	var pad_press := InputEventJoypadButton.new()
	pad_press.device = 4
	pad_press.button_index = JOY_BUTTON_A
	pad_press.pressed = true
	director._input(pad_press)
	director._on_joy_connection_changed(5, false)
	expect(director.active(), "unrelated controller disconnect does not cancel owned input")
	director._on_joy_connection_changed(4, false)
	expect(not director.active() and outcomes.back() == &"cancelled", "owning controller disconnect cancels safely")
	now[0] = 0.0
	director.begin(sequence(gate()))
	director.interaction_resolved.connect(func(_result: CADResult) -> void: director.cancel(), CONNECT_ONE_SHOT)
	director._input(edge())
	expect(not director.active() and director.results.is_empty(), "nested cancellation cannot commit a route")
	var count := outcomes.size()
	director._process(0.0)
	expect(outcomes.size() == count, "nested cancellation emits one terminal outcome")
	director.begin(sequence(gate()))
	var active_runner := director.interaction_runner
	director.free()
	expect(active_runner.last_result.grade == &"cancelled" and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER),
		"scene unload cancels runner and releases input lease")
	var invalid := sequence(gate())
	invalid.beats[0].gate.interaction.routes[&"success"] = &"missing_destination"
	expect(not invalid.validation_errors().is_empty(), "typed grade routes are checked against the existing graph")

func lab_contract() -> void:
	var episode: TEEpisode = load("res://content/qte_lab/episode.tres")
	expect(TEValidator.check(episode).is_empty(), "resource-authored lab episode validates")
	Flow.save_slot = -1
	Flow.new_game(episode)
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	director._input(edge())
	var outcome: StringName = await Flow.episode_finished
	expect(outcome == &"success" and Story.result(&"lab", &"windup") == "dodge", "new interaction drives paired stage reaction and legacy story result")
	Flow.new_game(episode)
	await Flow.director_started
	outcome = await Flow.episode_finished
	expect(outcome == &"missed" and Story.result(&"lab", &"windup") == "timeout", "new interaction timeout follows authored failure timeline")
	Flow.stop()
	Flow.save_slot = 0
	await frames(3)
