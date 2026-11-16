extends "res://tests/test_interaction.gd"
## Direction uses deterministic raw native events; synthetic pad events do not
## certify physical controller behaviour.

func run() -> void:
	analogue_contract()
	rearm_contract()
	diagonal_contract()
	hold_direction_contract()
	selection_contract()
	source_contract()
	camera_contract()
	prompt_contract()
	validation_direction_contract()
	lifecycle_direction_contract()

func direction_gate(mode: CADInteractionSpec.DirectionMode = CADInteractionSpec.DirectionMode.FLICK) -> CADGate:
	var value := gate()
	value.options[0].action = &"cad_dir_left"
	value.interaction.family = CADInteractionSpec.Family.DIRECTION
	value.interaction.actions = []
	value.interaction.direction_mode = mode
	return value

func direction_runner(spec: CADGate, held: Array[InputEvent] = [], context: Dictionary = {}) -> CADInteractionRunner:
	now[0] = 0.0
	var value := CADInteractionRunner.new(func() -> float: return now[0], func() -> Array[InputEvent]: return held)
	expect(value.begin(spec, spec.options, 1.0, 1, 1, &"direction", context), "direction spec acquires shared runner")
	return value

func motion(value: float, axis: JoyAxis = JOY_AXIS_LEFT_X, device := 0) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event

func key(value: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = value
	event.pressed = pressed
	return event

func dpad(value: JoyButton, pressed := true, device := 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = value
	event.pressed = pressed
	return event

func feed(value: CADInteractionRunner, event: InputEvent, at := 0.0) -> void:
	now[0] = at
	value.input(event, 1, 1)

func advance(value: CADInteractionRunner, at: float) -> void:
	now[0] = at
	value.tick()

func analogue_contract() -> void:
	var value := direction_runner(direction_gate())
	feed(value, motion(-0.1))
	feed(value, motion(-0.64))
	expect(value.active and value.router.controller == -1, "drift below activation neither resolves nor claims a controller")
	feed(value, motion(-0.65))
	expect(value.active, "sector decision waits for the short axis-coalescing interval")
	advance(value, 0.03)
	expect(value.last_result.grade == &"success" and value.last_result.direction == CADInteractionSpec.Sector.LEFT,
		"raw analogue activation boundary resolves left")
	expect(value.last_result.to_dict().direction == 6, "typed direction is additive scalar result data")
	var spec := direction_gate()
	spec.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
	value = direction_runner(spec)
	feed(value, motion(0.9))
	advance(value, 0.03)
	expect(value.last_result.grade == &"miss" and value.last_result.direction == 2, "wrong sector follows explicit fail policy")
	value = direction_runner(direction_gate())
	feed(value, motion(-0.9), 2.0)
	expect(value.last_result.grade == &"timeout", "late deflection cannot beat gate deadline")
	# These thresholds intentionally differ from InputMap's 0.2 deadzone.
	spec = direction_gate()
	spec.interaction.direction_activation = 0.15
	spec.interaction.direction_rearm = 0.05
	value = direction_runner(spec)
	feed(value, motion(-0.16))
	advance(value, 0.03)
	expect(value.last_result.grade == &"success" and CADInputDevice.using_pad, "raw strengths honour low authored thresholds and active-device prompts")

func rearm_contract() -> void:
	var held: Array[InputEvent] = [motion(-0.9)]
	var value := direction_runner(direction_gate(), held)
	feed(value, motion(-0.8))
	advance(value, 0.04)
	expect(value.active, "pre-held stick is blocked even if it jitters after acquisition")
	feed(value, motion(0.2), 0.05)
	feed(value, motion(-0.8), 0.06)
	advance(value, 0.09)
	expect(value.last_result.grade == &"success", "returning below rearm permits a fresh directional attempt")
	value = direction_runner(direction_gate())
	feed(value, motion(0.8))
	advance(value, 0.03)
	feed(value, motion(0.4), 0.1)
	feed(value, motion(-0.8), 0.2)
	advance(value, 0.24)
	expect(value.active, "wrong-to-correct sweep above neutral does not count as a fresh flick")
	feed(value, motion(0.25), 0.3)
	feed(value, motion(-0.8), 0.31)
	advance(value, 0.34)
	expect(value.last_result.grade == &"success", "hysteresis uses inclusive neutral threshold")
	Input.action_press(&"cad_dir_left")
	now[0] = 0.0
	value = CADInteractionRunner.new(func() -> float: return now[0])
	var spec := direction_gate()
	expect(value.begin(spec, spec.options, 1.0, 1, 1, &"held"), "default acquisition samples held logical actions")
	feed(value, edge(&"cad_dir_left"))
	advance(value, 0.03)
	expect(value.active, "held synthetic action cannot bypass default acquisition rearm")
	Input.action_release(&"cad_dir_left")
	feed(value, edge(&"cad_dir_left", false), 0.04)
	feed(value, edge(&"cad_dir_left"), 0.05)
	advance(value, 0.08)
	expect(value.last_result.grade == &"success", "logical release rearms synthetic input")

func diagonal_contract() -> void:
	for fps: float in [30.0, 60.0, 120.0]:
		var spec := direction_gate()
		spec.interaction.direction_eight_way = true
		spec.interaction.direction_sector = CADInteractionSpec.Sector.UP_LEFT
		spec.interaction.wrong_input = CADInteractionSpec.WrongInput.FAIL
		var value := direction_runner(spec)
		feed(value, motion(-0.9))
		feed(value, motion(-0.9, JOY_AXIS_LEFT_Y), 0.005)
		for frame in 5:
			advance(value, (frame + 1.0) / fps)
		expect(value.last_result.grade == &"success" and value.last_result.direction == 7,
			"coalesced diagonal is deterministic at %d FPS" % fps)
	var spec := direction_gate()
	spec.interaction.direction_eight_way = true
	spec.interaction.direction_sector = CADInteractionSpec.Sector.UP_LEFT
	var value := direction_runner(spec)
	feed(value, key(KEY_W))
	feed(value, key(KEY_A), 0.005)
	advance(value, 0.03)
	expect(value.last_result.direction == 7, "keyboard chord and analogue stick share diagonal sectors")
	expect(CADDirectionHandler.sector_of(Vector2(1, -1)) == 2, "four-way angular tie is deterministic clockwise")
	expect(CADDirectionHandler.sector_of(Vector2(1, -1), true) == 1, "eight-way policy gives diagonals their own sector")

func hold_direction_contract() -> void:
	var value := direction_runner(direction_gate(CADInteractionSpec.DirectionMode.HOLD))
	feed(value, motion(-0.8))
	advance(value, 0.03)
	feed(value, motion(-0.3), 0.2)
	advance(value, 0.53)
	expect(value.last_result.grade == &"success", "directional block maintains its sector through hysteresis band")
	value = direction_runner(direction_gate(CADInteractionSpec.DirectionMode.HOLD))
	feed(value, motion(-0.8))
	advance(value, 0.03)
	feed(value, motion(0.8), 0.2)
	feed(value, motion(-0.8), 0.21)
	advance(value, 0.8)
	expect(value.active and value.progress() == 0.0, "breaking block resets progress and requires neutral")
	feed(value, motion(0.0), 0.81)
	feed(value, motion(-0.8), 0.82)
	advance(value, 1.35)
	expect(value.last_result.grade == &"success", "fresh directional block recovers without restarting encounter")
	value = direction_runner(direction_gate(CADInteractionSpec.DirectionMode.HOLD))
	feed(value, motion(-0.8))
	advance(value, 5.0)
	expect(value.last_result.grade == &"success", "directional hold completed before a hitch retains success")

func selection_contract() -> void:
	var spec := direction_gate(CADInteractionSpec.DirectionMode.SELECT)
	var right := CADOption.new()
	right.id = &"right_route"
	right.action = &"cad_dir_right"
	right.next = &"lost"
	spec.options.append(right)
	spec.interaction.option_id = &""
	spec.interaction.direction_options = {6: &"go", 2: &"right_route"}
	var value := direction_runner(spec)
	feed(value, dpad(JOY_BUTTON_DPAD_RIGHT))
	advance(value, 0.03)
	expect(value.last_result.option_id == &"right_route" and value.last_result.route_id == &"lost", "D-pad direction selects stable option and graph destination")
	value = direction_runner(spec)
	feed(value, key(KEY_A))
	advance(value, 0.03)
	expect(value.last_result.option_id == &"go", "keyboard chooses the other authored direction route")
	now[0] = 0.0
	value = CADInteractionRunner.new(func() -> float: return now[0])
	expect(value.begin(spec, [spec.options[0]], 1.0, 1, 1, &"filtered"), "direction selection accepts flag-filtered offers")
	feed(value, motion(0.8))
	advance(value, 0.03)
	expect(value.active, "unavailable direction option cannot be selected")
	value.cancel()

func source_contract() -> void:
	var spec := direction_gate()
	spec.interaction.direction_eight_way = true
	spec.interaction.direction_sector = CADInteractionSpec.Sector.UP_LEFT
	var value := direction_runner(spec)
	feed(value, motion(-0.8))
	feed(value, key(KEY_W))
	advance(value, 0.03)
	expect(value.active, "stick and keyboard cannot combine into a phantom diagonal")
	feed(value, motion(0.0), 0.04)
	feed(value, key(KEY_W, false), 0.05)
	feed(value, key(KEY_W), 0.06)
	feed(value, key(KEY_A), 0.06)
	advance(value, 0.09)
	expect(value.last_result.direction == 7, "source switch works after neutral and fresh input")
	var held: Array[InputEvent] = [motion(-0.9, JOY_AXIS_LEFT_X, 0)]
	value = direction_runner(direction_gate(), held)
	feed(value, motion(-0.8, JOY_AXIS_LEFT_X, 3))
	feed(value, motion(0.0, JOY_AXIS_LEFT_X, 0), 0.01)
	advance(value, 0.03)
	expect(value.last_result.grade == &"success" and value.router.controller == 3, "pre-held non-owner pad cannot steal a fresh controller's input")
	var original := InputMap.action_get_events(&"cad_dir_left")
	InputMap.action_erase_events(&"cad_dir_left")
	var binding := key(KEY_F9, false)
	InputMap.action_add_event(&"cad_dir_left", binding)
	value = direction_runner(direction_gate())
	feed(value, key(KEY_A))
	advance(value, 0.03)
	expect(value.active, "removed direction key mapping is not hardcoded")
	feed(value, key(KEY_F9), 0.04)
	advance(value, 0.07)
	expect(value.last_result.grade == &"success", "remapped direction key uses current InputMap")
	InputMap.action_erase_events(&"cad_dir_left")
	for event in original:
		InputMap.action_add_event(&"cad_dir_left", event)

func camera_contract() -> void:
	var spec := direction_gate()
	spec.interaction.direction_space = CADInteractionSpec.DirectionSpace.CAMERA
	var context := {"camera_forward": Vector2.LEFT}
	var value := direction_runner(spec, [], context)
	context.camera_forward = Vector2.RIGHT
	feed(value, motion(-0.8, JOY_AXIS_LEFT_Y))
	advance(value, 0.03)
	expect(value.last_result.direction == 6, "camera-relative world left uses frozen forward snapshot")
	expect(CADDirectionHandler.input_sector(6, Vector2.LEFT, false) == 0, "prompt can invert the frozen camera frame into input direction")
	value = runner()
	expect(not value.begin(spec, spec.options, 1.0, 1, 1, &"missing") and "camera_forward" in value.last_error,
		"missing camera frame is an explicit acquisition error")
	var camera := Camera3D.new()
	add_child(camera)
	camera.rotation.y = PI / 2.0
	camera.make_current()
	now[0] = 0.0
	var director := CADDirector.new()
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	expect(director.begin(sequence(spec)), "director supplies active camera basis")
	camera.rotation.y = -PI / 2.0
	director._input(motion(-0.8, JOY_AXIS_LEFT_Y))
	now[0] = 0.03
	director._process(0.03)
	expect(director.results[&"test"] == &"go" and director.detailed_results[&"test"].direction == 6,
		"camera cuts during a gate cannot flip its input frame")
	director.free()
	camera.free()

func validation_direction_contract() -> void:
	var valid := direction_gate()
	expect(valid.interaction.validation_errors(valid.options, 2.0).is_empty(), "valid direction resource passes validation")
	for field: String in ["direction_activation", "direction_rearm", "direction_settle_seconds"]:
		var spec: CADGate = valid.duplicate(true)
		spec.interaction.set(field, NAN)
		expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "non-finite direction setting rejected: " + field)
	var spec: CADGate = valid.duplicate(true)
	spec.interaction.direction_rearm = spec.interaction.direction_activation
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "hysteresis thresholds must be ordered")
	spec = valid.duplicate(true)
	spec.interaction.direction_sector = CADInteractionSpec.Sector.UP_LEFT
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "four-way resource cannot silently request a diagonal")
	spec = valid.duplicate(true)
	spec.interaction.direction_actions[0] = &"missing_direction_action"
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "missing direction InputMap action is rejected")
	spec = direction_gate(CADInteractionSpec.DirectionMode.SELECT)
	spec.interaction.direction_options = {6: &"missing_option"}
	expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "direction map must name offered option IDs")

func lifecycle_direction_contract() -> void:
	for mode: CADInteractionSpec.DirectionMode in [CADInteractionSpec.DirectionMode.FLICK, CADInteractionSpec.DirectionMode.HOLD]:
		var held: Array[InputEvent] = []
		var spec := direction_gate(mode)
		var value := direction_runner(spec, held)
		feed(value, motion(-0.8))
		held.append(motion(-0.8))
		value.suspend(true)
		now[0] = 10.0
		value.tick()
		expect(value.active and value.clock.elapsed == 0.0, "direction pause freezes clock and pending decision")
		value.suspend(false)
		feed(value, motion(-0.9), 10.01)
		advance(value, 10.05)
		expect(value.active, "resume rejects stick that stayed held during pause")
		feed(value, motion(0.0), 10.06)
		feed(value, motion(-0.8), 10.07)
		advance(value, 10.65)
		expect(value.last_result.grade == &"success", "fresh direction after resume can finish")
		value = direction_runner(spec)
		feed(value, motion(-0.8))
		value.cancel()
		value.cancel()
		expect(value.last_result.grade == &"cancelled", "direction cancellation resolves once")
		var director := CADDirector.new()
		director.clock_source = func() -> float: return now[0]
		add_child(director)
		expect(director.begin(sequence(spec)), "direction works through shared director")
		var owned := director.interaction_runner
		director.free()
		expect(owned.last_result.grade == &"cancelled" and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER),
			"scene unloading releases directional state and input lease")

func prompt_contract() -> void:
	var spec := direction_gate()
	var text := CADPrompt.interaction_text(spec, spec.options, false)
	expect("[A]" in text, "directional keyboard prompt comes from InputMap")
	text = CADPrompt.interaction_text(spec, spec.options, true)
	expect("Left stick ←" in text and "D-pad ←" in text, "controller prompt shows stick and D-pad alternatives")
	spec.interaction.direction_space = CADInteractionSpec.DirectionSpace.CAMERA
	text = CADPrompt.interaction_text(spec, spec.options, false, Vector2.LEFT)
	expect("[W]" in text, "camera-relative prompt uses frozen inverse input direction")
	spec.interaction.direction_space = CADInteractionSpec.DirectionSpace.INPUT
	spec.interaction.direction_eight_way = true
	spec.interaction.direction_sector = CADInteractionSpec.Sector.UP_LEFT
	text = CADPrompt.interaction_text(spec, spec.options, true)
	expect("Left stick ↖" in text and "D-pad ↖" in text, "diagonal prompts remain compact")
	Screen.layout_prompt(4)
	expect(Screen.prompt_label.size.y >= 4 * 26 and Screen.prompt_bar.position.y > Screen.prompt_label.size.y,
		"overlay grows for visible directional choices without hiding the timer")
	Screen.layout_prompt(2)
