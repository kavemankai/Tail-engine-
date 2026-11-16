extends TestSuite
## Resource compilation, real stage playback, paired skeletal dispatch and Flow.

const COMBO := preload("res://examples/last_call/qte_lab/pattern/combo.tres")
const CHAIN := preload("res://examples/last_call/qte_lab/pattern/chain.tres")
const EPISODE := preload("res://examples/last_call/qte_lab/pattern/combo_episode.tres")
const STAGE := preload("res://examples/last_call/qte_lab/pattern/stage.tscn")
const ACTOR := preload("res://tests/fixtures/tree_actor.gd")

func run() -> void:
	compiler_contract()
	continuity_contract()
	skeletal_contract()
	for failed_component in [0, 1, 2, 3]:
		await playback_contract(COMBO, failed_component)
	await playback_contract(CHAIN, 0)
	await flow_contract()
	await frames(3)

func compiler_contract() -> void:
	for template: CADChainTemplate in [COMBO, CHAIN]:
		var first := template.build()
		var second := template.build()
		expect(first != null and first.validation_errors().is_empty() and first.beats.size() == 9, "chain compiles to ordinary validated beats")
		first.beats[0].gate.options[0].next = &"broken"
		expect(second.validation_errors().is_empty() and template.gates[0].options[0].next == &"", "builds isolate their gates and leave authoring resources unchanged")
	var invalid: CADThreePunchTemplate = COMBO.duplicate(true)
	invalid.gates.remove_at(0)
	expect(invalid.build() == null and not invalid.last_errors.is_empty(), "combo rejects fewer than three inputs")
	invalid = COMBO.duplicate(true)
	invalid.action_timelines[1] = invalid.action_timelines[0]
	expect(invalid.build() == null, "combo requires three distinct action timelines")
	invalid = COMBO.duplicate(true)
	invalid.gates[1].interaction.routes[&"success"] = &"input_1"
	expect(invalid.build() == null, "chain rejects cyclic grade overrides and skipped reactions")
	invalid = COMBO.duplicate(true)
	invalid.recovery_timelines = []
	expect(invalid.build() == null, "chain rejects missing recovery timelines")
	var path := "user://chain_test_%s.tres" % get_instance_id()
	expect(ResourceSaver.save(COMBO, path) == OK, "combo serialises as a native resource")
	var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CADThreePunchTemplate
	expect(restored != null and restored.build() != null, "saved combo reloads and compiles")
	DirAccess.remove_absolute(path)
	for name: String in ["alternating", "ordered", "combo", "chain"]:
		expect(TEValidator.check(load("res://examples/last_call/qte_lab/pattern/%s_episode.tres" % name)).is_empty(), "Pattern lab episode %s validates" % name)

func continuity_contract() -> void:
	var library: AnimationLibrary = load("res://examples/last_call/qte_lab/pattern/timelines.tres")
	for role: String in ["Player", "Aggressor"]:
		for name: StringName in [&"jab", &"cross", &"hook", &"block", &"recover"]:
			var animation := library.get_animation(name)
			var track := animation.find_track(NodePath(role + ":position"), Animation.TYPE_VALUE)
			var ready := library.get_animation(&"ready")
			var ready_track := ready.find_track(NodePath(role + ":position"), Animation.TYPE_VALUE)
			expect(animation.value_track_interpolate(track, 0.0).is_equal_approx(ready.value_track_interpolate(ready_track, 0.0))
				and animation.value_track_interpolate(track, animation.length).is_equal_approx(ready.value_track_interpolate(ready_track, 0.0)),
				"%s root remains continuous entering and leaving %s" % [role, name])

func skeletal_contract() -> void:
	var poses: Array[Quaternion] = []
	for clip: StringName in [&"punch_jab", &"punch_cross", &"punch_hook"]:
		var actor := ACTOR.new()
		add_child(actor)
		var stage := CADStage.new()
		add_child(stage)
		stage.bind(&"Player", actor)
		stage.act(&"Player", clip)
		actor.tree.advance(0.25)
		actor.tree.advance(0.25)
		poses.append(actor.rig.get_bone_pose_rotation(1))
		expect(poses.back().get_angle() > 0.1 and actor.position == Vector3.ZERO, "%s changes skeletal pose without displacing actor root" % clip)
		stage.free()
		actor.free()
	expect(not poses[0].is_equal_approx(poses[1]) and not poses[0].is_equal_approx(poses[2]) and not poses[1].is_equal_approx(poses[2]),
		"three fixture punch animations have distinct skeletal poses")

func playback_contract(template: CADChainTemplate, failed_component: int) -> void:
	var stage: CADStage = STAGE.instantiate()
	add_child(stage)
	stage.timelines.speed_scale = 6.0
	var player := ACTOR.new()
	var npc := ACTOR.new()
	add_child(player)
	add_child(npc)
	stage.bind(&"Player", player)
	stage.bind(&"Aggressor", npc)
	var director := CADDirector.new()
	var now := [0.0]
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	var graph := template.build()
	var respond := func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
		var number := int(String(beat.id).get_slice("_", 1))
		if number == failed_component:
			now[0] += 2.0
			director._process(0.0)
		else:
			now[0] += 0.1
			var event := InputEventAction.new()
			event.action = &"cad_dir_left" if beat.gate.interaction.family == CADInteractionSpec.Family.DIRECTION else beat.gate.interaction.actions[0]
			event.pressed = true
			director._input(event)
			if beat.gate.interaction.family == CADInteractionSpec.Family.DIRECTION:
				now[0] += 0.4
				director._process(0.0)
			event.pressed = false
			director._input(event)
	director.gate_opened.connect(respond)
	expect(director.begin(graph, stage), "chain starts through shared director and stage")
	var outcome: StringName = await director.finished
	var completed := 3 if failed_component == 0 else failed_component - 1
	expect(outcome == (&"completed" if failed_component == 0 else &"interrupted"), "component %s takes authored completion or recovery" % failed_component)
	expect(director.results.size() == (3 if failed_component == 0 else failed_component), "each acquired component retains an independent result")
	for i in completed:
		var action := template.action_timelines[i]
		if action == &"block":
			expect(&"guard" in player.clips and &"windup" in npc.clips, "defence component plays paired block choreography")
		else:
			expect(StringName("punch_" + String(action)) in player.clips and StringName("recoil_" + String(action)) in npc.clips,
				"accepted %s input dispatches punch and corresponding NPC reaction" % action)
	if failed_component > 0:
		var next_clip := StringName("punch_" + String(template.action_timelines[failed_component - 1]))
		expect(next_clip not in player.clips and director.results[StringName("input_" + str(failed_component))] == &"timeout", "missed component cannot play its successful strike")
	if failed_component == 0 and template == COMBO:
		var punches := player.clips.filter(func(clip: StringName) -> bool: return String(clip).begins_with("punch_"))
		expect(punches == [&"punch_jab", &"punch_cross", &"punch_hook"], "three distinct punches dispatch once and in authored order")
	await frames(1)
	director.free()
	stage.free()
	player.free()
	npc.free()
	await frames(2)

func flow_contract() -> void:
	Flow.save_slot = -1
	Flow.new_game(EPISODE)
	var director: CADDirector = await Flow.director_started
	var respond := func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
		tap(beat.gate.interaction.actions[0])
	director.gate_opened.connect(respond)
	respond.call(COMBO.build().beats[0], COMBO.gates[0].options, 1.8)
	var outcome: StringName = await Flow.episode_finished
	expect(outcome == &"completed" and Story.results[&"lab"].size() == 3, "native combo episode writes three compatible results through Flow")
	Flow.new_game(EPISODE)
	director = await Flow.director_started
	var runner := director.interaction_runner
	Flow.stop()
	await frames(3)
	expect(runner.last_result.grade == &"cancelled" and Story.results.is_empty()
		and not get_viewport().has_meta(CADDirector.VIEWPORT_OWNER), "unloading chain cancels without durable partial results or input lease")
	Flow.save_slot = 0
