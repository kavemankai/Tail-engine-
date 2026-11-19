extends TestSuite
## Phase 6: QTE assists, dialogue direction tags, the actor interface, jaw-bone
## lip-sync, cutscene voice/sound/clip waits, and the Timeline step.

const TONE_A := preload("res://tests/fixtures/tone_a.wav")
const TONE_B := preload("res://tests/fixtures/tone_b.wav")
const PLACEHOLDER := preload("res://addons/tale_engine/placeholder_actor.tscn")
const LOCATION_PATH := "user://test_direction_location.tscn"
const SCRIPT := """~ start
hero: Look over there. [#emote=angry] [#gesture=point] [#look=friend]
friend: Me? [#clip=hero:wave] [#look=none]
=> END
"""

func run() -> void:
	runner_assists()
	await director_assists()
	jaw_bone()
	await dialogue_tags()
	build_location()
	await cutscene_cues()
	await timeline()
	await timeline_skip()
	validator()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCATION_PATH))
	Settings.text_hold_scale = 1.0
	Engine.time_scale = 1.0

# --- Assists -----------------------------------------------------------------

func gesture_gate(gesture: CADInteractionSpec.Gesture, hold := 0.5) -> CADGate:
	var option := CADOption.new()
	option.id = &"go"
	option.action = &"cad_a"
	option.next = &"done"
	var spec := CADInteractionSpec.new()
	spec.id = &"press"
	spec.family = CADInteractionSpec.Family.GESTURE
	spec.gesture = gesture
	spec.actions = [&"cad_a"]
	spec.option_id = &"go"
	spec.hold_seconds = hold
	var gate := CADGate.new()
	gate.options = [option]
	gate.interaction = spec
	gate.window_seconds = 2.0
	gate.timeout_next = &"missed"
	return gate

func choice_gate() -> CADGate:
	var gate := CADGate.new()
	for id: StringName in [&"left", &"right"]:
		var option := CADOption.new()
		option.id = id
		option.action = &"cad_a" if id == &"left" else &"cad_b"
		option.next = id
		gate.options.append(option)
	var spec := CADInteractionSpec.new()
	spec.id = &"pick"
	spec.family = CADInteractionSpec.Family.CHOICE
	gate.interaction = spec
	gate.window_seconds = 2.0
	gate.timeout_next = &"missed"
	return gate

func action_event(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event

func runner_assists() -> void:
	var now := [0.0]
	var clock := func() -> float: return now[0]
	var runner := CADInteractionRunner.new(clock)
	runner.auto_complete = true
	var gate := gesture_gate(CADInteractionSpec.Gesture.PRESS)
	expect(runner.begin(gate, gate.options, 1.0, 1, 1, &"beat"), "a press gate opens with auto-complete on")
	now[0] = 0.2
	runner.tick()
	expect(runner.active, "auto-complete waits a moment so the prompt is seen")
	now[0] = 0.4
	runner.tick()
	expect(not runner.active and runner.last_result.grade == &"success" and runner.last_result.option_id == &"go",
		"then the skill prompt succeeds by itself")

	now[0] = 0.0
	runner = CADInteractionRunner.new(clock)
	runner.auto_complete = true
	gate = choice_gate()
	runner.begin(gate, gate.options, 1.0, 1, 1, &"beat")
	now[0] = 1.0
	runner.tick()
	expect(runner.active, "a choice between options is never made for the player")
	runner.cancel()

	for toggle: bool in [false, true]:
		now[0] = 0.0
		runner = CADInteractionRunner.new(clock)
		runner.hold_toggle = toggle
		gate = gesture_gate(CADInteractionSpec.Gesture.HOLD, 0.5)
		runner.begin(gate, gate.options, 1.0, 1, 1, &"beat")
		runner.input(action_event(&"cad_a", true), 1, 1)
		now[0] = 0.05
		runner.input(action_event(&"cad_a", false), 1, 1)
		now[0] = 0.6
		runner.tick()
		if toggle:
			expect(not runner.active and runner.last_result.grade == &"success", "hold-toggle: one tap latches the hold to completion")
		else:
			expect(runner.active, "without hold-toggle a released hold does not complete")
			runner.cancel()

	now[0] = 0.0
	runner = CADInteractionRunner.new(clock)
	runner.hold_toggle = true
	gate = gesture_gate(CADInteractionSpec.Gesture.HOLD, 0.5)
	runner.begin(gate, gate.options, 1.0, 1, 1, &"beat")
	runner.input(action_event(&"cad_a", true), 1, 1)
	runner.input(action_event(&"cad_a", false), 1, 1)
	now[0] = 0.2
	runner.input(action_event(&"cad_a", true), 1, 1)
	now[0] = 0.8
	runner.tick()
	expect(runner.active, "hold-toggle: a second tap lets go")
	runner.cancel()

func legacy_sequence(hold: float) -> CADSequence:
	var option := CADOption.new()
	option.id = &"go"
	option.action = &"cad_a"
	option.next = &"complete"
	option.hold_seconds = hold
	var gate := CADGate.new()
	gate.options = [option]
	gate.window_seconds = 1.5
	gate.timeout_next = &"missed"
	var beat := CADBeat.new()
	beat.id = &"one"
	beat.gate = gate
	beat.watchdog_seconds = 3.0
	var sequence := CADSequence.new()
	sequence.entry = &"one"
	sequence.beats = [beat]
	sequence.outcomes = [&"complete", &"missed"]
	return sequence

func director_assists() -> void:
	var director := CADDirector.new()
	add_child(director)
	director.auto_complete = true
	var started := Time.get_ticks_msec()
	expect(director.begin(legacy_sequence(0.0)), "a legacy prompt starts with auto-complete on")
	expect(await director.finished == &"complete" and Time.get_ticks_msec() - started < 1200,
		"a single-option legacy prompt completes by itself before its window ends")
	director.auto_complete = false
	director.hold_toggle = true
	director.begin(legacy_sequence(0.3))
	await frames(2)
	tap(&"cad_a")
	expect(await director.finished == &"complete", "hold-toggle: a tap latches a legacy hold prompt")
	director.queue_free()

# --- Actors ------------------------------------------------------------------

func jaw_bone() -> void:
	var actor := TEActor.new()
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("head")
	var jaw := skeleton.add_bone("jaw")
	skeleton.set_bone_parent(jaw, 0)
	actor.add_child(skeleton)
	add_child(actor)
	actor.set_mouth_open(1.0)
	var angle := skeleton.get_bone_pose_rotation(jaw).get_angle()
	expect(is_equal_approx(rad_to_deg(angle), actor.jaw_open_degrees), "a rig without mouth blend shapes opens its jaw bone")
	actor.set_mouth_open(0.0)
	expect(is_zero_approx(skeleton.get_bone_pose_rotation(jaw).get_angle()), "and closes it again")
	actor.free()

func cast_actor(id: StringName, at: Vector3) -> TEActor:
	var character := TECharacter.new()
	character.id = id
	character.display_name = String(id)
	character.clips = {&"emote_happy": &"smile"}
	var actor: TEActor = PLACEHOLDER.instantiate()
	actor.setup(character)
	add_child(actor)
	actor.global_position = at
	return actor

func dialogue_tags() -> void:
	Settings.text_hold_scale = 0.75
	Engine.time_scale = 8.0
	var hero := cast_actor(&"hero", Vector3.ZERO)
	var friend := cast_actor(&"friend", Vector3(0, 0, -3))
	Flow.actors = {&"hero": hero, &"friend": friend}
	var resource := DialogueManager.create_resource_from_text(SCRIPT)
	var seen: Array = []
	var on_line := func(line: DialogueLine) -> void:
		if line.character == "hero":
			seen.append([hero.emotion, hero.clip_log.duplicate(), hero.look_target])
	var on_open := func(balloon: TEBalloon) -> void: balloon.line_shown.connect(on_line)
	Flow.balloon_opened.connect(on_open)
	await Flow.converse(resource, "start")
	Flow.balloon_opened.disconnect(on_open)
	expect(not seen.is_empty() and seen[0][0] == &"angry", "[#emote=] sets the speaker's emotion")
	expect(not seen.is_empty() and &"gesture_point" in seen[0][1], "[#gesture=] plays the speaker's gesture")
	expect(not seen.is_empty() and seen[0][2] is Vector3 and seen[0][2].distance_to(Vector3(0, 1.6, -3)) < 0.01,
		"[#look=] aims at another cast member's eye height")
	expect(&"wave" in hero.clip_log, "[#clip=hero:wave] on another speaker's line plays that clip on hero")
	expect(friend.look_target == null, "[#look=none] clears the look")
	hero.emote(&"happy")
	expect(&"smile" in hero.clip_log, "the default emote plays a mapped emote_<name> clip")
	Flow.actors = {}
	hero.free()
	friend.free()
	Engine.time_scale = 1.0

# --- Cutscenes and timelines ---------------------------------------------------

func build_location() -> void:
	var root := TELocation.new()
	root.name = "DirectionFixture"
	var marks := Node3D.new()
	marks.name = "Marks"
	root.add_child(marks)
	var start := Marker3D.new()
	start.name = "start"
	marks.add_child(start)
	var shots := Node3D.new()
	shots.name = "Shots"
	root.add_child(shots)
	for shot_name: String in ["wide", "close"]:
		var camera := Camera3D.new()
		camera.name = shot_name
		shots.add_child(camera)
	var cues := TETimelineCues.new()
	cues.name = "Cues"
	root.add_child(cues)
	var player := AnimationPlayer.new()
	player.name = "Timeline"
	root.add_child(player)
	var animation := Animation.new()
	animation.length = 1.2
	var track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track, ^"Cues")
	animation.track_insert_key(track, 0.0, {"method": &"shot", "args": ["wide"]})
	animation.track_insert_key(track, 0.05, {"method": &"caption", "args": ["Opening"]})
	animation.track_insert_key(track, 0.1, {"method": &"clip", "args": ["hero", "wave"]})
	animation.track_insert_key(track, 0.6, {"method": &"sound", "args": [TONE_B.resource_path]})
	animation.track_insert_key(track, 0.7, {"method": &"caption", "args": ["Closing"]})
	animation.track_insert_key(track, 0.75, {"method": &"shot", "args": ["close", 0.2]})
	var library := AnimationLibrary.new()
	library.add_animation(&"intro", animation)
	player.add_animation_library(&"", library)
	for node in [marks, start, shots, shots.get_child(0), shots.get_child(1), cues, player]:
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	expect(ResourceSaver.save(scene, LOCATION_PATH) == OK, "fixture location saved")
	root.free()

func episode_with(step: TEStep) -> TEEpisode:
	var episode := TEEpisode.new()
	episode.id = &"direction"
	episode.title = "Direction"
	episode.manifest = TEStoryManifest.new()
	episode.cast = TECast.new()
	var hero := TECharacter.new()
	hero.id = &"hero"
	hero.display_name = "Hero"
	episode.cast.characters = [hero]
	episode.player = &"hero"
	step.location = LOCATION_PATH
	step.cast = {&"hero": "start"}
	var exit := TEExit.new()
	exit.on = &"*"
	exit.next = Flow.END
	step.exits = [exit]
	episode.steps = [step]
	episode.entry = step.id
	return episode

func cutscene_cues() -> void:
	Flow.save_slot = -1
	var cue := TEShotCue.new()
	cue.shot = &"wide"
	cue.hold = 0.1
	cue.speaker = &"hero"
	cue.voice = TONE_A
	cue.sound = TONE_B
	cue.clips = {&"hero": &"wave"}
	cue.emotes = {&"hero": &"happy"}
	cue.wait_for_clip = &"hero"
	var step := TEStep.new()
	step.id = &"cut"
	step.kind = TEStep.Kind.CUTSCENE
	step.cues = [cue]
	var episode := episode_with(step)
	expect(TEValidator.check(episode).is_empty(), "a cutscene with voice, sound and a clip wait validates: %s" % ", ".join(TEValidator.check(episode)))
	Flow.new_game(episode)
	await Flow.step_started
	await frames(3)
	var hero: TEActor = Flow.actors[&"hero"]
	expect(Audio.speaking_actor() == hero and hero.emotion == &"happy" and &"wave" in hero.clip_log,
		"a cue voices its speaker, sets emotions and plays clips")
	expect(Audio.effects_playing() >= 1, "a cue plays its sound")
	var started := Time.get_ticks_msec()
	await Flow.episode_finished
	expect(Time.get_ticks_msec() - started >= 1500, "a voiced cue lasts as long as its recording")
	Flow.stop()

func timeline() -> void:
	var step := TEStep.new()
	step.id = &"intro"
	step.kind = TEStep.Kind.TIMELINE
	step.timeline = &"intro"
	var episode := episode_with(step)
	expect(TEValidator.check(episode).is_empty(), "a timeline step validates: %s" % ", ".join(TEValidator.check(episode)))
	var captions: Array[String] = []
	var finished: Array = []
	var on_finish := func(s: TEStep, exit_name: StringName) -> void: finished.append(exit_name)
	Flow.step_finished.connect(on_finish)
	Flow.new_game(episode)
	await Flow.step_started
	while finished.is_empty():
		var text: String = Screen._caption.text
		if text != "" and (captions.is_empty() or captions.back() != text):
			captions.append(text)
		await get_tree().process_frame
	Flow.step_finished.disconnect(on_finish)
	expect(finished == [&"end"], "a timeline step ends with exit end")
	expect(captions == ["Opening", "Closing"], "method tracks set captions in order")
	expect(Flow.camera.current != null and Flow.camera.current.name == "close", "method tracks cut and blend the camera")
	await Flow.episode_finished
	Flow.stop()

func timeline_skip() -> void:
	var step := TEStep.new()
	step.id = &"intro"
	step.kind = TEStep.Kind.TIMELINE
	step.timeline = &"intro"
	var episode := episode_with(step)
	Audio.stop_effects()
	var finished: Array = []
	var on_finish := func(s: TEStep, exit_name: StringName) -> void: finished.append(exit_name)
	Flow.step_finished.connect(on_finish)
	Flow.new_game(episode)
	await Flow.step_started
	await wait(0.2)
	tap(&"te_advance")
	await frames(1)
	expect(finished.is_empty() and Screen._hint.text.contains("skip"), "the first press asks before skipping")
	tap(&"te_advance")
	await frames(3)
	Flow.step_finished.disconnect(on_finish)
	expect(finished == [&"end"], "the second press skips to the end")
	expect(Screen._caption.text == "" and Audio.effects_playing() == 0, "a skip fires none of the remaining cues")
	await Flow.episode_finished
	Flow.stop()
	Flow.save_slot = 0

func validator() -> void:
	var step := TEStep.new()
	step.id = &"intro"
	step.kind = TEStep.Kind.TIMELINE
	step.timeline = &"missing"
	var errors := TEValidator.check(episode_with(step))
	expect(Array(errors).any(func(e: String) -> bool: return e.contains("animation 'missing'")), "the validator reports a missing timeline animation")
	var cue := TEShotCue.new()
	cue.shot = &"wide"
	cue.wait_for_clip = &"nobody"
	var cut := TEStep.new()
	cut.id = &"cut"
	cut.kind = TEStep.Kind.CUTSCENE
	cut.cues = [cue]
	errors = TEValidator.check(episode_with(cut))
	expect(Array(errors).any(func(e: String) -> bool: return e.contains("waits for unknown character 'nobody'")), "the validator reports a clip wait on an unknown character")
