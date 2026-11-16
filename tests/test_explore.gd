extends TestSuite
## Walking around a hub and using hotspots.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	Flow.save_slot = -1
	Settings.text_hold_scale = 0.05
	Flow.new_game(EPISODE)
	var hub: TEHub = await Flow.hub_entered
	var actor: TEActor = Flow.actors[&"player"]
	await frames(3)
	expect(hub.current == null and Screen._hint.text == "", "no prompt away from hotspots")

	# Walk with real movement input from the spawn to the stool.
	var start := actor.global_position
	var walker := AutoPlayer.new()
	add_child(walker)
	walker._target = hub.get_node("Stool")
	while hub.current == null:
		await get_tree().physics_frame
	walker._target = null
	walker._steer(Vector3.ZERO)
	expect(actor.global_position.distance_to(start) > 1.0 and absf(actor.global_position.y) < 0.05, "player walked across the floor")
	expect(hub.current.name == &"Stool" and "Look" in Screen._hint.text, "nearest hotspot shows its prompt")
	tap(&"te_interact")
	await frames(1)
	while hub._busy:
		await frames(1)
	await frames(2)
	expect(Story.flag(&"stool_noticed"), "interact ran the hotspot's dialogue")
	expect(hub.current == null and not hub.available(hub.get_node("Stool")), "a once-only hotspot is spent")

	# Fixed camera zone at the counter.
	var zone: TECameraZone = Flow.location.get_node("Zones/AtCounter")
	expect(get_viewport().get_camera_3d() != zone.camera(), "follow camera away from the zone")
	walker._target = hub.get_node("Bartender")
	while walker._distance() > 0.9:
		await get_tree().physics_frame
	walker._target = null
	walker._steer(Vector3.ZERO)
	await frames(2)
	expect(get_viewport().get_camera_3d() == zone.camera(), "camera zone takes over near the counter")
	expect(actor.global_position.z > -1.2, "the counter blocked the player")

	var finished: Array = []
	Flow.step_finished.connect(func(_step: TEStep, exit_name: StringName) -> void: finished.append(exit_name), CONNECT_ONE_SHOT)
	hub.use(hub.get_node("Stranger"))
	expect(finished == [&"confront"], "exit hotspot ended the hub step")
	Flow.stop()
	walker.free()
	Settings.text_hold_scale = 1.0
	Flow.save_slot = 0
