extends TestSuite
## Camera direction: cuts, blends, drifting shots, shake and cutscene steps.

const LOCATION_PATH := "user://camera_suite_location.tscn"

func run() -> void:
	Flow.save_slot = -1
	Settings.text_hold_scale = 1.0
	await cuts_and_blends()
	await drifting_shot()
	await shake_settles()
	await cutscene_step()
	Flow.stop()
	await frames(3)
	DirAccess.remove_absolute(LOCATION_PATH)
	Flow.save_slot = 0

func make_camera(at: Vector3, fov := 75.0, shot := false) -> Camera3D:
	var camera: Camera3D = TEShot.new() if shot else Camera3D.new()
	camera.fov = fov
	add_child(camera)
	camera.global_position = at
	return camera

func cuts_and_blends() -> void:
	var rig := TECamera.new()
	add_child(rig)
	var a := make_camera(Vector3(0, 0, 0))
	var b := make_camera(Vector3(10, 0, 0), 40.0)
	rig.cut_to(a)
	await frames(2)
	expect(get_viewport().get_camera_3d() == a, "cut_to makes the camera current")
	rig.blend_to(b, 0.3)
	await frames(2)
	expect(rig.is_blending() and get_viewport().get_camera_3d() != a and get_viewport().get_camera_3d() != b,
		"a blend flies a transient camera")
	var mid := get_viewport().get_camera_3d().global_position.x
	expect(mid > 0.0 and mid < 10.0, "the blend camera is between the two shots")
	await wait(0.5)
	expect(not rig.is_blending() and get_viewport().get_camera_3d() == b, "the blend lands on the target shot")
	rig.blend_to(a, 0.0)
	await frames(2)
	expect(get_viewport().get_camera_3d() == a and not rig.is_blending(), "a zero-length blend is a cut")
	rig.blend_to(b, 5.0)
	await frames(2)
	rig.cut_to(a)
	await frames(2)
	expect(not rig.is_blending() and get_viewport().get_camera_3d() == a, "a cut cancels a blend in flight")
	rig.stop()
	for node: Node in [rig, a, b]:
		node.free()

func drifting_shot() -> void:
	var rig := TECamera.new()
	add_child(rig)
	var shot := make_camera(Vector3(0, 1, 5), 70.0, true) as TEShot
	shot.drift = Vector3(0, 0, -2)
	shot.fov_drift = -10.0
	shot.drift_time = 0.3
	shot._ready()
	rig.cut_to(shot)
	await wait(0.5)
	expect(is_equal_approx(shot.global_position.z, 3.0), "a drifting shot pushes in over its drift time")
	expect(is_equal_approx(shot.fov, 60.0), "a drifting shot changes field of view")
	var other := make_camera(Vector3(2, 1, 5))
	rig.cut_to(other)
	expect(is_equal_approx(shot.global_position.z, 5.0) and is_equal_approx(shot.fov, 70.0), "leaving a shot restores its rest pose")
	rig.stop()
	for node: Node in [rig, shot, other]:
		node.free()

func shake_settles() -> void:
	var rig := TECamera.new()
	add_child(rig)
	var camera := make_camera(Vector3.ZERO)
	rig.cut_to(camera)
	await frames(2)
	rig.shake(0.5, 0.2)
	await frames(3)
	expect(camera.h_offset != 0.0 or camera.v_offset != 0.0, "shake offsets the view")
	await wait(0.4)
	rig.cut_to(camera)
	expect(camera.h_offset == 0.0 and camera.v_offset == 0.0, "the view is steady once shake ends")
	rig.stop()
	for node: Node in [rig, camera]:
		node.free()

func cutscene_step() -> void:
	var location := TELocation.new()
	var shots := Node3D.new()
	shots.name = "Shots"
	location.add_child(shots)
	for shot_name: String in ["one", "two"]:
		var camera := Camera3D.new()
		camera.name = shot_name
		camera.position = Vector3(0 if shot_name == "one" else 4, 1, 5)
		shots.add_child(camera)
		camera.owner = location
	shots.owner = location
	var packed := PackedScene.new()
	packed.pack(location)
	ResourceSaver.save(packed, LOCATION_PATH)
	location.free()

	var cue_one := TEShotCue.new()
	cue_one.shot = &"one"
	cue_one.hold = 0.15
	cue_one.caption = "First."
	var cue_two := TEShotCue.new()
	cue_two.shot = &"two"
	cue_two.blend = 0.05
	cue_two.hold = 0.15
	cue_two.caption = "Second."
	var exit := TEExit.new()
	exit.next = Flow.END
	var step := TEStep.new()
	step.id = &"scene"
	step.kind = TEStep.Kind.CUTSCENE
	step.location = LOCATION_PATH
	step.cues = [cue_one, cue_two] as Array[TEShotCue]
	step.exits = [exit] as Array[TEExit]
	var episode := TEEpisode.new()
	episode.id = &"cutscene_probe"
	episode.manifest = TEStoryManifest.new()
	var player := TECharacter.new()
	player.id = &"player"
	episode.cast = TECast.new()
	episode.cast.characters = [player] as Array[TECharacter]
	episode.player = &"player"
	episode.entry = &"scene"
	episode.steps = [step] as Array[TEStep]
	expect(TEValidator.check(episode).is_empty(), "a well-formed cutscene validates")
	cue_two.shot = &"missing"
	expect(not TEValidator.check(episode).is_empty(), "a cue with a missing shot is reported")
	cue_two.shot = &"two"

	var finished: Array = []
	Flow.step_finished.connect(func(done: TEStep, exit_name: StringName) -> void: finished.append([done.id, exit_name]), CONNECT_ONE_SHOT)
	Flow.new_game(episode)
	await Flow.step_started
	await frames(3)
	var first_view := get_viewport().get_camera_3d()
	expect(first_view != null and is_equal_approx(first_view.global_position.x, 0.0), "the first cue cut to its shot")
	await Flow.episode_finished
	expect(finished == [[&"scene", &"end"]], "a cutscene ends with the end exit and no input")
	expect(Screen._caption.text == "", "no caption is left over")
