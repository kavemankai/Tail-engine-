extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cast: TECast = load("res://content/episode_0/cast.tres")
	for c: TECharacter in cast.characters:
		var actor: TEActor = c.actor_scene.instantiate()
		actor.setup(c)
		root.add_child(actor)
		await process_frame
		actor.cad_act(&"counter")
		if actor.body.animator.player.assigned_animation != &"Punch_Jab":
			push_error("Animation dispatch failed for " + c.display_name)
			quit(1)
			return
		print("ADAPTER ", c.id, " Punch_Jab")
		actor.queue_free()
		await process_frame
	quit(0)
