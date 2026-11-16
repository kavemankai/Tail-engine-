extends "res://tests/test_interaction.gd"
## Mutable scalar target snapshots model moving/hidden/deleted stage targets.

var targets: Array = []

func run() -> void:
	selection_contract()
	tracking_contract()
	lifecycle_target_contract()
	validation_target_contract()
	native_target_contract()
	stage_target_contract()
	Screen.prompt_label.text = "Aim [A / D / W / S]\nCycle [Space / K]\nSelect [J]"
	Screen.layout_prompt(3)
	expect(Screen.prompt_bar.position.y >= Screen.prompt_label.position.y + Screen.prompt_label.size.y + 8.0,
		"three-line target prompt keeps progress below shaped text")
	expect(Screen.prompt_bar.position.y + Screen.prompt_bar.size.y <= Screen.prompt_backdrop.size.y,
		"theme minimum progress size fits inside prompt backdrop")
	await attachments_contract()
	await bone_attachment_contract()
	await grab_flow_contract()

func target_gate(lock := 0.0) -> CADGate:
	var value := gate()
	value.interaction.family = CADInteractionSpec.Family.TARGET
	value.interaction.actions = []
	value.interaction.target_options = {&"a": &"go", &"b": &"go"}
	value.interaction.target_lock_seconds = lock
	return value

func acquire(value: CADInteractionRunner, lock := 0.0) -> void:
	targets = [{"id": &"b", "position": Vector2(0.8, 0.5)}, {"id": &"a", "position": Vector2(0.3, 0.5)}]
	var spec := target_gate(lock)
	expect(value.begin(spec, spec.options, 1.0, 1, 1, &"beat", {"target_snapshot": func() -> Array: return targets, "target_extent": Vector2(1.5, 1.0)}), "Target acquires an injected registry snapshot")

func selection_contract() -> void:
	var value := runner()
	acquire(value)
	expect(value.target_view().focused == &"a", "initial focus and tie breaks use stable target IDs, not insertion order")
	value.input(edge(&"cad_b"), 1, 1)
	expect(value.target_view().focused == &"b", "next focus cycles to the other eligible target")
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"success" and value.last_result.target_id == &"b" and value.last_result.option_id == &"go", "target result separates stable target and route option")
	expect(value.last_result.to_dict().target_id == "b", "target identity serialises as a scalar")
	value = runner()
	acquire(value)
	value.input(edge(&"cad_dodge"), 1, 1)
	expect(value.target_view().focused == &"b", "previous focus wraps deterministically")
	value.cancel()
	value = runner()
	acquire(value)
	targets = []
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active and value.target_view().focused == &"", "no eligible target cannot be confirmed")
	now[0] = 2.0
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"timeout" and value.last_result.target_id == &"", "no-target and late input follow timeout route")
	value = runner()
	acquire(value)
	targets = [{"id": &"a", "position": Vector2(0.3, 0.5)}, {"id": &"b", "position": Vector2(0.3, 0.5)}]
	value.tick()
	expect(value.target_view().focused == &"a", "overlapping targets break distance ties by stable ID")
	value.cancel()

func tracking_contract() -> void:
	for fps in [30, 60, 120]:
		var value := runner()
		acquire(value, 0.4)
		value.input(edge(&"cad_a"), 1, 1)
		for frame in range(1, int(fps * 0.4) + 1):
			now[0] = float(frame) / fps
			value.tick()
		expect(value.last_result != null and value.last_result.grade == &"success", "held target lock is deterministic at %s FPS" % fps)
	var value := runner()
	acquire(value, 0.4)
	value.input(edge(&"cad_a"), 1, 1)
	now[0] = 0.1
	value.tick()
	expect(value.progress() > 0.0 and value.active, "tracking exposes continuous bounded lock progress")
	targets[1].position = Vector2(0.6, 0.5)
	now[0] = 0.2
	value.tick()
	expect(value.progress() == 0.0 and value.target_view().focused == &"", "moving out of reticle interrupts lock")
	value.input(edge(&"cad_dir_right"), 1, 1)
	for frame in 5:
		now[0] += 0.1
		value.tick()
	value.input(edge(&"cad_dir_right", false), 1, 1)
	expect(value.target_view().focused == &"a", "shared directional routing moves reticle to reacquire moving target")
	value.input(edge(&"cad_a", false), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	for frame in 4:
		now[0] += 0.1
		value.tick()
	expect(value.last_result != null and value.last_result.target_id == &"a", "fresh confirm can lock a reacquired target")
	value = runner()
	acquire(value, 0.4)
	value.input(edge(&"cad_a"), 1, 1)
	now[0] = 0.6
	value.tick()
	expect(value.active and value.progress() == 0.0, "a hitch earns no unobserved lock credit")
	targets = [{"id": &"b", "position": Vector2(0.3, 0.5)}]
	now[0] += 0.1
	value.tick()
	expect(value.active and value.progress() == 0.0 and value.target_view().focused == &"b", "switching target resets lock and requires fresh confirm")
	value.cancel()

func lifecycle_target_contract() -> void:
	var value := runner()
	acquire(value, 0.4)
	value.input(edge(&"cad_a"), 1, 1)
	now[0] = 0.1
	value.tick()
	value.suspend(true)
	now[0] = 10.0
	value.input(edge(&"cad_a"), 1, 1)
	value.tick()
	expect(value.progress() == 0.0 and value.active, "pause resets lock and ignores paused input")
	value.suspend(false)
	value.input(edge(&"cad_a"), 1, 1)
	for frame in 4:
		now[0] += 0.1
		value.tick()
	expect(value.last_result != null and value.last_result.grade == &"success", "fresh lock after resume excludes paused wall time")
	value = runner()
	acquire(value)
	var count := [0]
	value.resolved.connect(func(_result: CADResult) -> void: count[0] += 1)
	value.cancel()
	value.cancel()
	expect(count[0] == 1 and value.last_result.grade == &"cancelled" and value.target_view().is_empty(), "Target cancellation resolves once and clears presentation")
	now[0] = 0.0
	acquire(value)
	value.input(edge(&"cad_a"), 0, 1)
	expect(value.active and value.target_view().focused == &"a", "restart and stale run rejection retain fresh target state")
	value.cancel()
	Input.action_press(&"cad_a")
	value = runner()
	acquire(value)
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.active, "preheld confirm cannot select a newly opened target")
	Input.action_release(&"cad_a")
	value.input(edge(&"cad_a", false), 1, 1)
	value.input(edge(&"cad_a"), 1, 1)
	expect(value.last_result.grade == &"success", "owned release rearms target confirm")

func validation_target_contract() -> void:
	var spec := target_gate()
	var value := runner()
	expect(not value.begin(spec, spec.options, 1.0, 1, 1, &"beat"), "Target rejects missing provider before acquiring input")
	for change in ["mapping", "controls", "radius", "duration", "nan", "directions"]:
		spec = target_gate()
		match change:
			"mapping": spec.interaction.target_options[&"a"] = &"missing"
			"controls": spec.interaction.target_confirm_action = spec.interaction.target_next_action
			"radius": spec.interaction.target_radius = 0.0
			"duration": spec.interaction.target_lock_seconds = 3.0
			"nan": spec.interaction.target_cursor_speed = NAN
			"directions": spec.interaction.direction_actions = []
		expect(not spec.interaction.validation_errors(spec.options, 2.0).is_empty(), "invalid Target %s is rejected" % change)

func attachments_contract() -> void:
	var prop := MeshInstance3D.new()
	var socket := Node3D.new()
	add_child(prop)
	add_child(socket)
	prop.position = Vector3(1, 1, 0)
	var original := prop.global_transform
	var attachments := CADPropAttachments.new()
	expect(attachments.attach(prop, socket) and prop.global_transform.is_equal_approx(original), "socket contact retains authored global offset without snapping")
	socket.position.x += 2.0
	await frames(2)
	expect(is_equal_approx(prop.position.x, 3.0) and prop.get_parent() == self, "socket movement carries scene-owned prop without reparenting")
	attachments.detach(prop)
	socket.position.x += 1.0
	await frames(2)
	expect(is_equal_approx(prop.position.x, 3.0), "authored detach releases transform ownership")
	attachments.release(true)
	expect(prop.global_transform.is_equal_approx(original), "cancellation restores original prop state even after authored detach")
	attachments.attach(prop, socket)
	socket.position.x += 1.0
	await frames(2)
	var final := prop.global_transform
	attachments.release(false)
	expect(prop.global_transform.is_equal_approx(final), "normal release preserves authored final prop placement")
	attachments.attach(prop, socket)
	socket.free()
	await frames(2)
	attachments.release(true)
	expect(is_instance_valid(prop) and prop.global_transform.is_equal_approx(final), "actor/socket deletion does not delete prop and cleanup restores acquisition pose")
	expect(not attachments.attach(prop, null), "invalid attachment socket returns an explicit failure")
	prop.free()
	await frames(2)

func native_target_contract() -> void:
	var value := runner()
	acquire(value)
	var aim := InputEventJoypadMotion.new()
	aim.device = 2
	aim.axis = JOY_AXIS_LEFT_X
	aim.axis_value = 0.7
	value.input(aim, 1, 1)
	var confirm := InputEventJoypadButton.new()
	confirm.device = 3
	confirm.button_index = JOY_BUTTON_X
	confirm.pressed = true
	value.input(confirm, 1, 1)
	expect(value.active and value.router.controller == 2, "aim acquires controller and another pad cannot confirm its target")
	confirm.device = 2
	value.input(confirm, 1, 1)
	expect(value.last_result.grade == &"success", "owned pad confirms through current InputMap bindings")
	var original := InputMap.action_get_events(&"cad_a")
	InputMap.action_erase_events(&"cad_a")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	InputMap.action_add_event(&"cad_a", key)
	value = runner()
	acquire(value)
	key.pressed = true
	value.input(key, 1, 1)
	expect(value.last_result.grade == &"success" and "F8" in CADPrompt.interaction_text(target_gate(), target_gate().options, false), "Target confirm and prompt use remapped controls")
	InputMap.action_erase_events(&"cad_a")
	for binding in original:
		InputMap.action_add_event(&"cad_a", binding)

func stage_target_contract() -> void:
	var stage: CADStage = load("res://content/qte_lab/target/stage.tscn").instantiate()
	add_child(stage)
	stage.cut(&"Wide")
	var registry := stage.target_registry
	var snapshot := registry.snapshot([&"bottle", &"crate"], {})
	expect(snapshot.size() == 1 and snapshot[0].id == &"crate", "narrative eligibility filters projected scene targets")
	snapshot = registry.snapshot([&"bottle", &"crate"], {&"saw_bottle": true})
	if snapshot.size() != 2 or snapshot[0].id != &"bottle":
		print("TARGET DIAGNOSTIC ", snapshot, " bindings=", registry.targets, " requires=", registry.requires, " viewport=", get_viewport().get_visible_rect(), " camera=", get_viewport().get_camera_3d())
	expect(snapshot.size() == 2 and snapshot[0].id == &"bottle" and snapshot[0].position.is_finite(), "registry projects eligible visible targets in stable order")
	registry.target(&"crate").hide()
	expect(registry.snapshot([&"crate"], {}).is_empty(), "hidden target is not selectable")
	expect(not registry.validation_errors([&"missing"]).is_empty(), "registry rejects absent target bindings")
	var graph: CADSequence = load("res://content/qte_lab/target/selection.tres")
	var no_socket := TEActor.new()
	add_child(no_socket)
	stage.bind(&"Player", no_socket)
	var grab: CADGrabTemplate = load("res://content/qte_lab/target/grab.tres")
	expect("socket" in "\n".join(stage.validation_errors(grab.build())), "runtime stage validation rejects a bound actor missing its authored socket")
	stage.unbind(&"Player")
	no_socket.free()
	registry.targets.erase(&"bottle")
	expect(not stage.validation_errors(graph).is_empty(), "stage validation catches authored target IDs before input acquisition")
	stage.free()

func grab_flow_contract() -> void:
	const EPISODE = preload("res://content/qte_lab/target/grab_episode.tres")
	for name in ["selection", "tracking", "grab"]:
		expect(TEValidator.check(load("res://content/qte_lab/target/%s_episode.tres" % name)).is_empty(), "target episode %s validates" % name)
	Flow.save_slot = -1
	Flow.new_game(EPISODE)
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	var stage := Flow.location.stage(&"TargetStage")
	var prop := stage.target_registry.target(&"bottle")
	var original := prop.global_transform
	var attached := [false]
	var moved := [false]
	director.beat_started.connect(func(beat: CADBeat, _visit: int) -> void:
		if beat.id == &"action_1":
			await wait(0.3)
			if is_instance_valid(stage) and director.active():
				attached[0] = not stage.prop_attachments._records.is_empty()
			await wait(0.2)
			if is_instance_valid(prop): moved[0] = not prop.global_transform.is_equal_approx(original))
	tap(&"cad_a")
	var outcome: StringName = await Flow.episode_finished
	expect(outcome == &"completed" and attached[0] and moved[0], "shared grab template runs selected-result socket markers and carries the prop")
	expect(Story.result(&"lab", &"input_1") == "bottle" and stage.prop_attachments._records.is_empty(), "grab preserves legacy result and releases socket ownership on finish")
	Flow.new_game(EPISODE)
	director = await Flow.director_started
	await director.gate_opened
	stage = Flow.location.stage(&"TargetStage")
	prop = stage.target_registry.target(&"bottle")
	original = prop.global_transform
	tap(&"cad_a")
	await wait(0.5)
	expect(not stage.prop_attachments._records.is_empty(), "grab reached contact before interruption")
	director.cancel()
	expect(prop.global_transform.is_equal_approx(original) and stage.prop_attachments._records.is_empty(), "director cancellation restores contacted prop deterministically")
	Flow.stop()
	await frames(3)
	expect(not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "unloaded target/grab releases input ownership")
	Flow.save_slot = 0

func bone_attachment_contract() -> void:
	var actor: TEActor = load("res://tests/fixtures/tree_actor.gd").new()
	add_child(actor)
	var socket := BoneAttachment3D.new()
	socket.bone_name = "hand"
	actor.rig.add_child(socket)
	var prop := RigidBody3D.new()
	prop.freeze = false
	add_child(prop)
	var attachments := CADPropAttachments.new()
	expect(attachments.attach(prop, socket) and prop.freeze, "real BoneAttachment3D socket freezes held rigid prop")
	var original := prop.global_transform
	actor.cad_act(&"punch_hook")
	actor.tree.advance(0.25)
	actor.tree.advance(0.25)
	await frames(3)
	expect(not prop.global_transform.is_equal_approx(original), "skeletal bone motion carries the prop through the socket adapter")
	attachments.release(true)
	expect(not prop.freeze and prop.global_transform.is_equal_approx(original), "cancel restores rigid-body freeze state and original pose")
	prop.free()
	actor.free()
	await frames(2)
