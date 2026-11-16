extends "res://tests/test_interaction.gd"

func run() -> void:
	context_contract()
	predicate_validation()
	await playback_contract()
	await skeletal_speed_contract()

func context_contract() -> void:
	var spec := gate()
	spec.interaction.option_intents = {&"go": &"restrain"}
	spec.interaction.momentum_changes = {&"success": 2, &"miss": -2}
	var graph := sequence(spec)
	graph.momentum_limit = 3
	graph.actor_statuses = {&"Player": &"ready"}
	graph.prop_states = {&"bottle": true}
	var director := CADDirector.new()
	director.clock_source = func() -> float: return now[0]
	add_child(director)
	var details: Array[CADResult] = []
	director.interaction_resolved.connect(func(result: CADResult) -> void:
		details.append(result)
		director._on_interaction_resolved(result))
	expect(director.begin(graph), "semantic encounter begins on existing graph")
	director._input(edge())
	expect(details.size() == 1 and details[0].intent_id == &"restrain" and director.context.momentum == 2,
		"semantic intent and momentum apply once despite a duplicate nested callback")
	expect(director.context.intent == &"restrain" and director.results[&"test"] == &"go", "semantic context preserves independent legacy option results")
	var snapshot := director.context.to_dict()
	snapshot.actors.Player = "mutated"
	expect(director.context.actor_statuses[&"Player"] == &"ready", "context snapshot contains isolated scalar data")
	director._process(0)
	expect(director.last_outcome == &"won", "semantic result follows existing route lifecycle")
	director.begin(graph)
	spec.interaction.momentum_changes[&"success"] = 100
	director._input(edge())
	expect(director.context.momentum == 2, "momentum uses the acquired immutable spec snapshot")
	director.cancel()
	director.begin(graph)
	expect(director.context.momentum == 0 and director.context.intent == &"", "new encounter resets momentum and semantic intent")
	director.cancel()
	expect(director.context.momentum == 0, "cancellation applies no momentum effect")
	director.free()
	var context := CADEncounterContext.new()
	context.configure(graph)
	var result := CADResult.new()
	result.grade = &"success"
	result.momentum_delta = 2
	context.apply(result)
	context.apply(result)
	expect(context.momentum == 3, "encounter momentum saturates at authored limit")
	result.grade = &"miss"
	result.momentum_delta = -2
	context.apply(result)
	context.apply(result)
	expect(context.momentum == 0, "momentum cannot fall below zero")
	var beat := CADBeat.new()
	beat.actor_changes = {&"Player": &"injured"}
	beat.prop_changes = {&"bottle": false}
	context.enter(beat)
	for kind in CADContextPredicate.Kind.values():
		var predicate := CADContextPredicate.new()
		predicate.kind = kind
		predicate.minimum = 0
		predicate.subject = &"Player" if kind == CADContextPredicate.Kind.ACTOR_STATUS else &"bottle"
		predicate.value = &"injured" if kind == CADContextPredicate.Kind.ACTOR_STATUS else &"defend"
		predicate.expected = false
		context.intent = &"defend"
		expect(predicate.matches(context), "typed context predicate evaluates kind %s" % kind)
	graph = sequence(gate())
	graph.actor_statuses = {&"Player": &"ready"}
	var decision := CADBeat.new()
	decision.id = &"decision"
	decision.next = &"lost"
	decision.watchdog_seconds = 1.0
	decision.actor_changes = {&"Player": &"injured"}
	var branch := CADBranch.new()
	branch.requires = &"observed"
	branch.next = &"won"
	branch.predicate = CADContextPredicate.new()
	branch.predicate.kind = CADContextPredicate.Kind.ACTOR_STATUS
	branch.predicate.subject = &"Player"
	branch.predicate.value = &"injured"
	decision.branches = [branch]
	graph.beats[0].gate.options[0].next = &"decision"
	graph.beats.append(decision)
	director = CADDirector.new()
	add_child(director)
	director.flags = {&"observed": true}
	expect(director.begin(graph), "typed adaptive branch validates with legacy flag conjunction")
	director._input(edge())
	director._process(0)
	director.marker(&"done", director._visit)
	director._process(0)
	expect(director.last_outcome == &"won", "authored actor change and flag select a prevalidated follow-through")
	director.free()

func predicate_validation() -> void:
	for change in ["speed", "limit", "start", "actor", "prop", "intent", "grade"]:
		var graph := sequence(gate())
		match change:
			"speed": graph.beats[0].playback_scale = NAN
			"limit": graph.momentum_limit = 101
			"start": graph.momentum_start = 4
			"actor": graph.beats[0].actor_changes = {&"Ghost": &"ready"}
			"prop": graph.beats[0].prop_changes = {&"Ghost": true}
			"intent": graph.beats[0].gate.interaction.option_intents = {&"go": &"unknown"}
			"grade": graph.beats[0].gate.interaction.momentum_changes = {&"cancelled": 1}
		expect(not graph.validation_errors().is_empty(), "invalid cinematic/context field %s is rejected" % change)

func playback_contract() -> void:
	var stage: CADStage = load("res://examples/last_call/qte_lab/pressure/stage.tscn").instantiate()
	add_child(stage)
	var actor := TEActor.new()
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	actor.add_child(player)
	add_child(actor)
	player.speed_scale = 1.5
	stage.timelines.speed_scale = 2.0
	stage.bind(&"Player", actor)
	stage.bind(&"Aggressor", actor)
	var director := CADDirector.new()
	add_child(director)
	stage.acquire(director)
	stage.set_playback_scale(0.25)
	expect(is_equal_approx(stage.timelines.speed_scale, 0.5) and is_equal_approx(player.speed_scale, 0.375), "local scope scales timeline and actor from their original speeds")
	expect(Engine.time_scale == 1.0, "local cinematic slowdown never changes global timescale")
	stage.unbind(&"Player")
	expect(is_equal_approx(player.speed_scale, 0.375), "shared actor role unbind retains other role's playback ownership")
	stage.unbind(&"Aggressor")
	expect(is_equal_approx(player.speed_scale, 1.5), "last role unbind restores original actor playback")
	stage.release()
	expect(is_equal_approx(stage.timelines.speed_scale, 2.0), "stage release restores original timeline speed")
	stage.bind(&"Player", actor)
	var graph := sequence(gate())
	graph.beats[0].timeline = &"ready"
	graph.beats[0].playback_scale = 0.25
	now[0] = 0
	director.clock_source = func() -> float: return now[0]
	expect(director.begin(graph, stage), "slow cinematic encounter begins")
	expect(is_equal_approx(director._watchdog_for(graph.beats[0]), 8.2), "derived watchdog accounts for base timeline speed and local slowdown")
	now[0] = 2.0
	director._process(0)
	expect(director.interaction_runner.last_result.grade == &"timeout", "real active-time input deadline remains independent of timeline slowdown")
	director._process(0)
	expect(player.speed_scale == 1.5 and stage.timelines.speed_scale == 2.0, "terminal encounter restores all acquired speeds")
	director.begin(graph, stage)
	director.suspend(true)
	director.cancel()
	expect(player.speed_scale == 1.5 and stage.timelines.speed_scale == 2.0, "cancellation while paused restores speed ownership")
	director.begin(graph, stage)
	var invalid_actor := TEActor.new()
	var invalid_tree := AnimationTree.new()
	invalid_actor.add_child(invalid_tree)
	add_child(invalid_actor)
	expect(not stage.bind(&"Player", invalid_actor) and stage.actor(&"Player") == actor, "live slowdown rejects an unsupported replacement without losing the current role")
	invalid_actor.free()
	director.free()
	expect(player.speed_scale == 1.5 and stage.timelines.speed_scale == 2.0, "director unloading restores speeds")
	stage.acquire(CADDirector.new())
	# Own this temporary director explicitly; Node references are not refcounted.
	var scope_director := stage._director
	stage.set_playback_scale(0.5)
	stage.free()
	expect(player.speed_scale == 1.5, "stage unloading restores actor playback even without a live director")
	scope_director.free()
	actor.free()
	await frames(3)

func skeletal_speed_contract() -> void:
	var rotations: Array[float] = []
	for speed in [1.0, 0.25]:
		var actor: TEActor = load("res://tests/fixtures/tree_actor.gd").new()
		add_child(actor)
		var scope := CADPlaybackScope.new()
		scope.add(actor)
		scope.set_scale(speed)
		actor.cad_act(&"punch_hook")
		actor.tree.advance(0.2)
		actor.tree.advance(0.2)
		rotations.append(actor.rig.get_bone_pose_rotation(1).get_angle())
		scope.clear()
		expect(is_equal_approx(actor.cad_playback_speed(), 1.0), "skeletal adapter restores AnimationTree TimeScale")
		actor.free()
	expect(rotations[0] > rotations[1] + 0.1, "scoped slowdown changes actual skeletal playback, not just timeline speed")
	await frames(2)
