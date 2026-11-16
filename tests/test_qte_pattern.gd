extends "res://tests/test_interaction.gd"
## Pattern edges pass through the real router; all timing is deterministic.

func run() -> void:
	ordered_contract()
	policies_contract()
	deadline_contract()
	lifecycle_contract()
	native_contract()
	validation_pattern_contract()

func pattern_gate(steps: Array[StringName] = [&"cad_a", &"cad_b", &"cad_a"]) -> CADGate:
	var spec := gate()
	spec.interaction.family = CADInteractionSpec.Family.PATTERN
	spec.interaction.actions = []
	spec.interaction.pattern_steps = steps
	for _step in steps:
		spec.interaction.pattern_deadlines.append(0.6)
	spec.interaction.pattern_min_seconds = 0.05
	return spec

func step_tap(value: CADInteractionRunner, action: StringName, at: float) -> void:
	now[0] = at
	value.input(edge(action), 1, 1)
	value.input(edge(action, false), 1, 1)

func ordered_contract() -> void:
	var value := runner()
	begin(value, pattern_gate())
	step_tap(value, &"cad_a", 0.1)
	expect(value.completed_steps() == 1 and is_equal_approx(value.progress(), 1.0 / 3.0), "first accepted step exposes bounded progress")
	step_tap(value, &"cad_b", 0.2)
	step_tap(value, &"cad_a", 0.3)
	expect(value.last_result.grade == &"success" and value.last_result.option_id == &"go" and value.progress() == 1.0, "alternation is ordinary repeated-action pattern data")
	value = runner()
	begin(value, pattern_gate([&"cad_a", &"cad_a"]))
	now[0] = 0.1
	value.input(edge(&"cad_a"), 1, 1)
	now[0] = 0.2
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active and value.completed_steps() == 1, "repeated press without owned release cannot advance repeated action")
	value.input(edge(&"cad_a", false), 1, 1)
	step_tap(value, &"cad_a", 0.3)
	expect(value.last_result.grade == &"success", "a fresh repeated action after release advances")
	value = runner()
	var spec := pattern_gate([&"cad_b", &"cad_dodge", &"cad_a"])
	begin(value, spec)
	for i in 3:
		step_tap(value, spec.interaction.pattern_steps[i], 0.1 * (i + 1))
	expect(value.last_result.grade == &"success", "ordered multi-action sequence shares the same evaluator")

	value = runner()
	spec = pattern_gate([&"cad_a", &"cad_b"])
	spec.interaction.pattern_min_seconds = 0.0
	begin(value, spec)
	step_tap(value, &"cad_a", 0.1)
	step_tap(value, &"cad_b", 0.1)
	expect(value.active and value.completed_steps() == 1, "simultaneous aliased controls cannot enter multiple ordered steps")
	value.cancel()

func policies_contract() -> void:
	for policy: CADInteractionSpec.PatternError in CADInteractionSpec.PatternError.values():
		var value := runner()
		var spec := pattern_gate()
		spec.interaction.pattern_error = policy
		begin(value, spec)
		step_tap(value, &"cad_a", 0.1)
		step_tap(value, &"cad_dodge", 0.2)
		if policy == CADInteractionSpec.PatternError.FAIL:
			expect(value.last_result.grade == &"miss" and value.last_result.progress > 0.0, "wrong action can fail with partial progress")
		elif policy == CADInteractionSpec.PatternError.RESET:
			expect(value.completed_steps() == 0 and value.progress() == 0.0, "wrong action resets the full pattern")
			step_tap(value, &"cad_a", 0.3)
			step_tap(value, &"cad_b", 0.4)
			step_tap(value, &"cad_a", 0.5)
			expect(value.last_result.grade == &"success", "reset pattern can recover inside original gate budget")
		else:
			expect(value.completed_steps() == 1, "ignore policy preserves accepted steps")
			step_tap(value, &"cad_b", 0.3)
			step_tap(value, &"cad_a", 0.4)
			expect(value.last_result.grade == &"success", "ignored wrong action does not prevent later success")
		value = runner()
		begin(value, spec)
		step_tap(value, &"cad_a", 0.01)
		expect(value.last_result.grade == &"miss" if policy == CADInteractionSpec.PatternError.FAIL else value.completed_steps() == 0,
			"too-early step uses explicit error policy %s" % policy)
		value.cancel()

func deadline_contract() -> void:
	for at in [0.6, 0.61, 8.0]:
		var value := runner()
		begin(value, pattern_gate())
		step_tap(value, &"cad_a", at)
		expect(value.last_result.grade == &"timeout" and value.last_result.progress == 0.0, "per-step deadline wins late edge at %s" % at)
	var value := runner()
	begin(value, pattern_gate())
	step_tap(value, &"cad_a", 0.2)
	now[0] = 0.8
	value.tick()
	expect(value.last_result.grade == &"timeout" and is_equal_approx(value.last_result.progress, 1.0 / 3.0), "next deadline is relative to previous accepted step")
	value = runner()
	var spec := pattern_gate()
	spec.window_seconds = 1.0
	begin(value, spec)
	step_tap(value, &"cad_a", 0.5)
	step_tap(value, &"cad_b", 0.95)
	step_tap(value, &"cad_a", 1.0)
	expect(value.last_result.grade == &"timeout", "overall gate deadline still wins when step budget remains")
	for fps in [30, 60, 120]:
		value = runner()
		begin(value, pattern_gate())
		for frame in range(1, fps / 2 + 1):
			now[0] = float(frame) / fps
			value.tick()
			if frame in [fps / 10, fps / 5, fps * 3 / 10]:
				step_tap(value, &"cad_b" if frame == fps / 5 else &"cad_a", now[0])
		expect(value.last_result != null and value.last_result.grade == &"success", "pattern is frame-rate independent at %s FPS" % fps)
	value = runner()
	spec = pattern_gate()
	expect(value.begin(spec, spec.options, 2.0, 1, 1, &"beat"), "assistance admits a wider overall budget")
	step_tap(value, &"cad_a", 0.8)
	step_tap(value, &"cad_b", 1.6)
	step_tap(value, &"cad_a", 2.4)
	expect(value.last_result.grade == &"success", "assistance widens relative deadlines without forcing faster input")

func lifecycle_contract() -> void:
	var value := runner()
	begin(value, pattern_gate())
	step_tap(value, &"cad_a", 0.1)
	value.suspend(true)
	now[0] = 20.0
	value.input(edge(&"cad_b"), 1, 1)
	value.tick()
	expect(value.active and value.completed_steps() == 0, "pause resets incomplete pattern and rejects paused input")
	value.suspend(false)
	step_tap(value, &"cad_a", 20.1)
	step_tap(value, &"cad_b", 20.2)
	step_tap(value, &"cad_a", 20.3)
	expect(value.last_result.grade == &"success", "fresh pattern after resume excludes paused wall time")
	value = runner()
	var count := [0]
	value.resolved.connect(func(_result: CADResult) -> void: count[0] += 1)
	begin(value, pattern_gate())
	step_tap(value, &"cad_a", 0.1)
	value.cancel()
	value.cancel()
	expect(count[0] == 1 and value.last_result.grade == &"cancelled", "cancellation resolves once without routing")
	now[0] = 0.0
	begin(value, pattern_gate())
	expect(value.completed_steps() == 0 and value.progress() == 0.0, "restart discards old pattern progress")
	value.input(edge(&"cad_a"), 0, 1)
	expect(value.completed_steps() == 0, "stale run input is rejected")
	value.cancel()
	var director := CADDirector.new()
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	director.begin(sequence(pattern_gate()))
	var active_runner := director.interaction_runner
	director.free()
	expect(active_runner.last_result.grade == &"cancelled" and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "scene unload cancels pattern and releases input lease")
	Input.action_press(&"cad_a")
	value = runner()
	begin(value, pattern_gate())
	step_tap(value, &"cad_a", 0.1)
	expect(value.completed_steps() == 0, "held input from previous prompt cannot advance pattern")
	Input.action_release(&"cad_a")
	value.input(edge(&"cad_a", false), 1, 1)
	step_tap(value, &"cad_a", 0.2)
	expect(value.completed_steps() == 1, "preheld input rearms after release")
	value.cancel()

func native_contract() -> void:
	var value := runner()
	begin(value, pattern_gate([&"cad_dodge", &"cad_b"]))
	var pad := InputEventJoypadButton.new()
	pad.device = 2
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	now[0] = 0.1
	value.input(pad, 1, 1)
	pad.pressed = false
	value.input(pad, 1, 1)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	now[0] = 0.2
	value.input(key, 1, 1)
	expect(value.last_result != null and value.last_result.grade == &"success", "keyboard/gamepad switch shares one ordered sequence")
	var spec := pattern_gate()
	var text := CADPrompt.interaction_text(spec, spec.options, false, Vector2.UP, 1)
	expect("→" in text and "✓" in text and CADPrompt.glyph(&"cad_b", false) in text, "prompt shows ordered remapped controls and accepted steps")

func validation_pattern_contract() -> void:
	for change: String in ["missing", "short", "negative", "nan", "empty", "many", "action", "policy", "interval"]:
		var spec := pattern_gate()
		match change:
			"missing": spec.interaction.pattern_steps[0] = &"missing_action"
			"short": spec.interaction.pattern_deadlines = [0.6]
			"negative": spec.interaction.pattern_deadlines[0] = -1.0
			"nan": spec.interaction.pattern_deadlines[0] = NAN
			"empty": spec.interaction.pattern_steps = []
			"many": spec.interaction.pattern_steps.resize(65)
			"action": spec.interaction.actions = [&"cad_a"]
			"policy": spec.interaction.set("pattern_error", 99)
			"interval": spec.interaction.pattern_min_seconds = 0.7
		expect(not spec.interaction.validation_errors(spec.options, spec.window_seconds).is_empty(), "invalid pattern %s is rejected" % change)
