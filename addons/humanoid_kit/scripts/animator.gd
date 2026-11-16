extends Node3D
## Owns the skinned model and blends. Does not read input or move the body.
signal action_finished(clip: StringName)

const MALE := preload("../source/Superhero_Male_FullBody.gltf")
const FEMALE := preload("../source/Superhero_Female_FullBody.gltf")
const IN_PLACE := preload("../animations/in_place.res")
const ROOT_MOTION := preload("../animations/root_motion.res")
const FADE := 0.16
const ACTIONS := {
	&"attack": &"Punch_Jab", &"melee": &"Sword_Attack", &"fire": &"Pistol_Shoot",
	&"hit": &"Hit_Chest", &"roll": &"Roll", &"interact": &"Interact",
	&"sit": &"Sitting_Enter", &"stand": &"Sitting_Exit",
}

var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var action: StringName
var dying := false
var previewing := false
var current_clip: StringName:
	get:
		return player.assigned_animation if is_instance_valid(player) else &""

func configure(female: bool, tint: Color, custom_model: PackedScene = null,
		extra_library: AnimationLibrary = null) -> void:
	if is_instance_valid(model):
		remove_child(model)
		model.queue_free()
	var scene: PackedScene = custom_model if custom_model != null else (FEMALE if female else MALE)
	model = scene.instantiate() as Node3D
	add_child(model)
	skeleton = model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if not is_instance_valid(skeleton):
		push_error("Humanoid model needs an imported GeneralSkeleton.")
		return
	skeleton.owner = model
	skeleton.unique_name_in_owner = true
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.83
	if custom_model == null:
		for mesh: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", true, false):
			if mesh.name == &"Eyebrows":
				mesh.hide()
			elif str(mesh.name).begins_with("Super"):
				mesh.material_override = material
	player = AnimationPlayer.new()
	model.add_child(player)
	player.add_animation_library(&"", IN_PLACE)
	player.add_animation_library(&"root_motion", ROOT_MOTION)
	if extra_library != null:
		player.add_animation_library(&"extra", extra_library)
	player.animation_finished.connect(_on_finished)
	action = &""
	previewing = false
	_play(&"Death01" if dying else &"Idle", 0.0)
	if dying:
		player.seek(player.get_animation(&"Death01").length, true)
		player.pause()

func available_clips() -> PackedStringArray:
	return player.get_animation_list()

func preview(clip: StringName) -> bool:
	if not player.has_animation(clip):
		return false
	action = &""
	previewing = true
	player.speed_scale = 1.0
	player.stop()
	_play(clip, 0.0)
	return true

func play_action(request: StringName) -> bool:
	var clip: StringName = ACTIONS.get(request, request)
	if dying or not player.has_animation(clip) or str(clip).begins_with("root_motion/"):
		return false
	if player.get_animation(clip).loop_mode != Animation.LOOP_NONE:
		return false
	if action == clip and player.is_playing():
		return false
	previewing = false
	action = clip
	player.speed_scale = 1.0
	_play(clip)
	return true

func die() -> void:
	dying = true
	previewing = false
	action = &""
	player.speed_scale = 1.0
	_play(&"Death01")

func reset() -> void:
	dying = false
	previewing = false
	action = &""
	player.speed_scale = 1.0
	_play(&"Idle")

func update_motion(speed: float, grounded: bool, stance: StringName, backwards: bool) -> void:
	if not is_instance_valid(player) or dying or previewing or not action.is_empty():
		return
	var clip := &"Idle"
	var cadence := 1.0
	if not grounded:
		clip = &"Jump"
	elif stance == &"sit":
		clip = &"Sitting_Idle"
	elif stance == &"aim":
		clip = &"Pistol_Aim_Neutral"
	elif stance == &"crouch":
		clip = &"Crouch_Fwd" if speed > 0.15 else &"Crouch_Idle"
		if speed > 0.15:
			cadence = clampf(speed / 1.05, 0.45, 1.9)
	elif backwards and speed > 0.15:
		clip = &"Walk"
		cadence = -clampf(speed / 1.65, 0.45, 2.0)
	elif speed > 4.5:
		clip = &"Sprint"
		cadence = speed / 5.6
	elif speed > 2.35:
		clip = &"Jog_Fwd"
		cadence = speed / 3.65
	elif speed > 0.15:
		clip = &"Walk"
		cadence = clampf(speed / 1.65, 0.45, 1.65)
	player.speed_scale = absf(cadence)
	var playback_direction := -1.0 if cadence < 0.0 else 1.0
	if current_clip != clip or (player.is_playing() and signf(player.get_playing_speed()) != playback_direction):
		player.play(clip, FADE, playback_direction, cadence < 0.0)

func _play(clip: StringName, fade := FADE) -> void:
	player.play(clip, fade)

func _on_finished(clip: StringName) -> void:
	if action == clip:
		action = &""
		action_finished.emit(clip)
