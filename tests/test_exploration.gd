extends TestSuite
## Phase 7: camera-relative movement, walk/idle, follow camera smoothing and
## collision, hotspot facing and highlight, examine view, inventory.

const PLACEHOLDER := preload("res://addons/tale_engine/placeholder_actor.tscn")

var player: TEActor
var floor_body: StaticBody3D

func run() -> void:
	directions()
	build_world()
	await camera_relative()
	await locomotion()
	await follow_camera()
	await facing_and_highlight()
	await examine()
	inventory()
	await item_hotspots()
	validator()
	player.free()
	floor_body.free()

func directions() -> void:
	var controller := TEPlayerController.new()
	controller.reference_yaw = 0.0
	expect(controller.world_direction(Vector2(0, -1)).is_equal_approx(Vector3(0, 0, -1)), "with the camera facing -Z, up walks to -Z")
	controller.reference_yaw = PI / 2.0
	expect(controller.world_direction(Vector2(0, -1)).is_equal_approx(Vector3(-1, 0, 0)), "with the camera turned left, up walks to -X")
	controller.camera_relative = false
	expect(controller.world_direction(Vector2(0, -1)).is_equal_approx(Vector3(0, 0, -1)), "camera_relative off keeps screen up as world -Z")
	controller.free()
	expect(is_equal_approx(TEPlayerController.camera_yaw(Basis.IDENTITY), 0.0), "an unrotated camera has yaw 0")
	expect(is_equal_approx(TEPlayerController.camera_yaw(Basis(Vector3.UP, 0.7)), 0.7), "yaw follows the camera's turn")

func build_world() -> void:
	floor_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.2, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.1
	add_child(floor_body)
	var character := TECharacter.new()
	character.id = &"hero"
	character.display_name = "Hero"
	character.clips = {&"walk": &"Walk_Loop", &"idle": &"Idle_Loop"}
	player = PLACEHOLDER.instantiate()
	player.setup(character)
	add_child(player)

func camera_at(yaw: float) -> Camera3D:
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = player.global_position + Vector3(0, 4, 0)
	camera.rotation.y = yaw
	camera.make_current()
	return camera

func camera_relative() -> void:
	var controller := TEPlayerController.new()
	player.add_child(controller)
	var first := camera_at(PI / 2.0)
	await physics(2)
	Input.action_press(&"move_forward")
	var start := player.global_position
	await physics(20)
	var moved := player.global_position - start
	expect(moved.x < -0.5 and absf(moved.z) < 0.1, "forward walks the way the camera faces")
	var second := camera_at(0.0)
	start = player.global_position
	await physics(15)
	moved = player.global_position - start
	expect(moved.x < -0.3 and absf(moved.z) < 0.1, "a camera cut keeps the old direction while the stick stays held")
	Input.action_release(&"move_forward")
	await physics(3)
	Input.action_press(&"move_forward")
	start = player.global_position
	await physics(15)
	moved = player.global_position - start
	expect(moved.z < -0.3 and absf(moved.x) < 0.1, "letting go and pressing again uses the new camera")
	var facing := -player.global_basis.z
	expect(facing.dot(Vector3(0, 0, -1)) > 0.8, "the body turns to face its heading")
	Input.action_release(&"move_forward")
	await physics(3)
	controller.free()
	first.free()
	second.free()

func locomotion() -> void:
	var controller := TEPlayerController.new()
	player.add_child(controller)
	player.clip_log.clear()
	Input.action_press(&"move_right")
	await physics(6)
	expect(player.clip_log.has(&"Walk_Loop"), "starting to move plays the mapped walk clip")
	Input.action_release(&"move_right")
	await physics(6)
	expect(player.clip_log.back() == &"Idle_Loop", "stopping plays the mapped idle clip")
	expect(player.clip_log.count(&"Walk_Loop") == 1, "the walk clip starts once, not every frame")
	controller.free()

func make_hub() -> TEHub:
	var hub := TEHub.new()
	hub.camera_smoothing = 6.0
	add_child(hub)
	return hub

func follow_camera() -> void:
	player.global_position = Vector3.ZERO
	var hub := make_hub()
	hub.activate(player, [], "follow")
	await frames(2)
	var camera := get_viewport().get_camera_3d()
	expect(camera.global_position.distance_to(player.global_position + hub.camera_offset) < 0.05, "the follow camera starts in place")
	player.global_position = Vector3(4, 0, 0)
	await frames(1)
	var lagging := camera.global_position.distance_to(player.global_position + hub.camera_offset)
	expect(lagging > 0.5, "the follow camera eases after the player instead of snapping")
	await wait(1.5)
	expect(camera.global_position.distance_to(player.global_position + hub.camera_offset) < 0.1, "and catches up")
	# A wall between the player and the camera pulls the camera in front of it.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 6, 0.2)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = player.global_position + Vector3(0, 1.5, 3.0)
	await physics(2)
	await wait(1.5)
	expect(camera.global_position.z < wall.global_position.z, "the follow camera stays on the player's side of a wall")
	hub.deactivate()
	wall.free()
	hub.free()

func hotspot(name: String, at: Vector3) -> TEHotspot:
	var spot := TEHotspot.new()
	spot.name = name
	spot.label = "Look"
	spot.radius = 2.0
	spot.exit = &"done"
	spot.position = at
	return spot

func facing_and_highlight() -> void:
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	var hub := make_hub()
	var behind := hotspot("Behind", Vector3(0, 0, 1.0))
	behind.facing_degrees = 60.0
	var glow := Node3D.new()
	glow.name = "Highlight"
	behind.add_child(glow)
	hub.add_child(behind)
	hub.activate(player, [], "facing")
	await frames(2)
	expect(hub.current == null, "a hotspot behind the player is not offered when it needs facing")
	expect(not glow.visible, "a hotspot that is not offered is not highlighted")
	player.rotation.y = PI
	await frames(2)
	expect(hub.current == behind and glow.visible, "turning to face it offers and highlights it")
	Screen._hint.text = "untouched"
	await frames(2)
	expect(Screen._hint.text == "untouched", "the hint is written when it changes, not every frame")
	player.rotation.y = 0.0
	await frames(2)
	expect(not glow.visible and Screen._hint.text == "", "turning away clears the highlight and the hint")
	hub.deactivate()
	hub.free()

func examine() -> void:
	player.global_position = Vector3.ZERO
	var hub := make_hub()
	var spot := hotspot("Letter", Vector3(0, 0, -1.0))
	var model := MeshInstance3D.new()
	model.mesh = BoxMesh.new()
	var scene := PackedScene.new()
	scene.pack(model)
	model.free()
	spot.examine_scene = scene
	spot.examine_text = "A letter, unsigned."
	hub.add_child(spot)
	hub.activate(player, [], "examine")
	var exits: Array = []
	hub.exited.connect(func(exit_name: StringName) -> void: exits.append(exit_name))
	await frames(2)
	hub.use(spot)
	await frames(2)
	var view := find_examine()
	expect(view != null and view.model is MeshInstance3D, "examining opens a close-up with the model")
	Input.action_press(&"move_right")
	await frames(10)
	Input.action_release(&"move_right")
	expect(view != null and not view.orientation().is_equal_approx(Basis.IDENTITY), "movement turns the model over")
	expect(exits.is_empty(), "the step does not move on while examining")
	tap(&"te_advance")
	await frames(3)
	expect(find_examine() == null and exits == [&"done"], "advance puts it down and the hotspot's exit follows")
	hub.deactivate()
	hub.free()

func find_examine() -> TEExamine:
	for node in get_tree().root.find_children("*", "TEExamine", true, false):
		if not node.is_queued_for_deletion():
			return node
	return null

func items_manifest() -> TEStoryManifest:
	var manifest := TEStoryManifest.new()
	manifest.items = {&"key": "Brass key", &"coin": "Coin"}
	return manifest

func inventory() -> void:
	Story.reset(items_manifest())
	expect(not Story.has_item(&"key"), "nothing is held at the start")
	Story.give(&"key")
	Story.give(&"coin", 3)
	expect(Story.has_item(&"key") and Story.item_count(&"coin") == 3, "items are given, with counts")
	expect(Story.take(&"coin", 2) and Story.item_count(&"coin") == 1, "items are taken")
	expect(not Story.take(&"coin", 5) and Story.item_count(&"coin") == 1, "taking more than is held fails and changes nothing")
	expect(Story.inventory() == PackedStringArray(["Brass key", "Coin"]), "the inventory lists display names")
	expect(TECondition.test("has_item('key')"), "conditions can test for an item")
	var faults := capture_faults()
	Story.give(&"ghost")
	release_faults()
	expect(faults.size() == 1 and not Story.has_item(&"ghost"), "an undeclared item is reported and not given")
	var saved := Story.to_dict()
	expect(TESave._story(saved), "a save with items is well formed")
	Story.reset(items_manifest())
	Story.from_dict(saved)
	expect(Story.has_item(&"key") and Story.item_count(&"coin") == 1, "items survive a save and load")
	var stale := saved.duplicate(true)
	stale["items"][&"removed"] = 1
	TESave._repair_story(stale, items_manifest())
	expect(not stale["items"].has(&"removed") and stale["items"].has(&"key"), "a patch that removes an item drops it from old saves")

func item_hotspots() -> void:
	Story.reset(items_manifest())
	player.global_position = Vector3.ZERO
	var hub := make_hub()
	var door := hotspot("Door", Vector3(0, 0, -1.0))
	door.requires_item = &"key"
	door.consumes_item = true
	hub.add_child(door)
	hub.activate(player, [], "door")
	var exits: Array = []
	hub.exited.connect(func(exit_name: StringName) -> void: exits.append(exit_name))
	await frames(2)
	expect(hub.current == door and Screen._hint.text.contains(tr("Needs %s") % "Brass key"), "a locked hotspot says what it needs")
	hub.use(door)
	await frames(2)
	expect(exits.is_empty(), "without the item the hotspot does nothing")
	Story.give(&"key")
	await frames(2)
	hub.use(door)
	await frames(2)
	expect(exits == [&"done"] and not Story.has_item(&"key"), "with the item it works and the item is used up")
	hub.deactivate()
	hub.free()
	Story.reset(TEStoryManifest.new())

func validator() -> void:
	var dialogue := DialogueManager.create_resource_from_text("~ start\nhero: Here. [ID:x1]\ndo Story.give(\"ghost\")\n=> END\n")
	var episode := TEEpisode.new()
	episode.manifest = items_manifest()
	episode.cast = TECast.new()
	var errors := PackedStringArray()
	var text := "do Story.give(\"ghost\")\nif Story.has_item(\"key\")"
	TEValidator.check_items(text, episode.manifest, "fixture", errors)
	expect(errors.size() == 1 and errors[0].contains("'ghost'"), "the validator reports undeclared items in dialogue")
	errors.clear()
	TEValidator.check_items("has_item('nope')", episode.manifest, "condition", errors)
	expect(errors.size() == 1, "and in conditions")
	expect(dialogue != null, "fixture dialogue parses")

func physics(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
