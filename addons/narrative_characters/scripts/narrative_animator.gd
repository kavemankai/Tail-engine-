extends "res://addons/humanoid_kit/scripts/animator.gd"
## Humanoid Kit animator + conversation layer.
##
## Extends the kit's own animator (crossfades, cadence, one-shot actions are
## unchanged) and adds: a conversation-aware choice of base clip, a
## SkeletonModifier3D for gestures/listening/look-at, and step-turning.
## It still exposes the interface humanoid.gd expects from `$Visual`.
signal gesture_finished(gesture_name: StringName)

const PoseModifier := preload("conversation_pose_modifier.gd")
const Profile := preload("conversation_profile.gd")

const CONV_FADE := 0.30
const TURN_RATE_ON := 0.9    # rad/s of body yaw that counts as "turning in place"
const TURN_RATE_OFF := 0.3

var profile: Resource = Profile.new()
var appearance: Resource   # CharacterAppearance (optional)
var modifier: SkeletonModifier3D
var conversation := false
var speaking := false
var listening := false
var emotion: StringName = &"neutral"
var seated_pose := false

var _free_arms_until := 0.0
var _now := 0.0   # engine-frame clock (deterministic under --fixed-fps / movie capture)
var _last_yaw := 0.0
var _yaw_rate := 0.0
var _turning := false
var _base_clip: StringName = &""

func configure(female: bool, tint: Color, custom_model: PackedScene = null,
		extra_library: AnimationLibrary = null) -> void:
	super.configure(female, tint, custom_model, extra_library)
	if not is_instance_valid(skeleton):
		return
	_apply_appearance()
	modifier = PoseModifier.new()
	modifier.name = "ConversationPoseModifier"
	skeleton.add_child(modifier)
	modifier.gesture_finished.connect(func(n: StringName) -> void: gesture_finished.emit(n))
	apply_profile(profile)
	var body := get_parent() as Node3D
	_last_yaw = body.rotation.y if body else 0.0

## Builds clothing, hair and anchors on top of the unmodified kit model.
func _apply_appearance() -> void:
	var a = appearance
	if a == null or not is_instance_valid(model):
		return
	var body_mi: MeshInstance3D
	for mi: MeshInstance3D in skeleton.find_children("*", "MeshInstance3D", false, false):
		if String(mi.name) in a.hidden_nodes:
			mi.hide()
		elif mi.name != &"Eyes" and body_mi == null:
			body_mi = mi
	if body_mi == null:
		push_error("NarrativeAnimator: kit body mesh not found")
		return
	if a.body_mesh != null:
		body_mi.mesh = a.body_mesh
	for part: Mesh in a.skinned_parts:
		var mi := MeshInstance3D.new()
		mi.name = "Cloth_%d" % skeleton.get_child_count()
		mi.mesh = part
		mi.skin = body_mi.skin
		skeleton.add_child(mi)
		mi.skeleton = NodePath("..")
	for spec in a.attachments:
		if skeleton.find_bone(spec.bone_name) < 0:
			push_warning("NarrativeAnimator: attachment bone '%s' missing" % spec.bone_name)
			continue
		var att := BoneAttachment3D.new()
		att.name = "Att_%s_%d" % [spec.bone_name, skeleton.get_child_count()]
		skeleton.add_child(att)
		att.bone_name = spec.bone_name
		var mi2 := MeshInstance3D.new()
		mi2.mesh = spec.mesh
		mi2.material_override = spec.material
		mi2.transform = spec.transform
		att.add_child(mi2)
	if skeleton.find_bone(&"Head") >= 0:
		var head_att := BoneAttachment3D.new()
		head_att.name = "HeadAnchors"
		skeleton.add_child(head_att)
		head_att.bone_name = &"Head"
		for anchor_name in a.head_anchors.keys():
			var mk := Marker3D.new()
			mk.name = String(anchor_name)
			mk.transform = a.head_anchors[anchor_name]
			head_att.add_child(mk)
			mk.owner = model
			mk.unique_name_in_owner = true
	model.scale = a.model_scale

func apply_profile(p: Resource) -> void:
	profile = p if p != null else Profile.new()
	if not is_instance_valid(modifier):
		return
	modifier.gesture_scale = profile.gesture_scale
	modifier.arm_scale = profile.arm_gesture_scale
	modifier.head_scale = profile.head_motion_scale
	modifier.breathing_scale = profile.breathing_scale
	modifier.look_max_yaw = deg_to_rad(profile.look_max_yaw_deg)
	modifier.look_max_pitch = deg_to_rad(profile.look_max_pitch_deg)
	modifier.look_speed = profile.look_speed

## Switch to a free-arms base clip for a short time (folded-arm idles).
func request_free_arms(seconds: float) -> void:
	_free_arms_until = maxf(_free_arms_until, _now + seconds)

func has_clip(clip: StringName) -> bool:
	return is_instance_valid(player) and player.has_animation(clip)

## The wanted clip if it exists, else the fallback (Idle). Missing-animation safety.
func clip_or_fallback(wanted: StringName, fallback: StringName = &"Idle") -> StringName:
	if has_clip(wanted):
		return wanted
	push_warning("NarrativeAnimator: clip '%s' missing, using '%s'" % [wanted, fallback])
	if has_clip(fallback):
		return fallback
	var all := player.get_animation_list()
	return StringName(all[0]) if all.size() > 0 else &""

## Debug/demo helper: crossfade to any kit clip with a chosen fade. Call end_preview() to resume.
func preview_blend(clip: StringName, fade: float) -> bool:
	if not has_clip(clip):
		return false
	action = &""
	previewing = true
	player.speed_scale = 1.0
	_base_clip = clip
	player.play(clip, fade)
	return true

func end_preview() -> void:
	previewing = false
	action = &""

func current_base_clip() -> StringName:
	return _base_clip

func is_turning() -> bool:
	return _turning

func reset_conversation() -> void:
	conversation = false
	speaking = false
	listening = false
	emotion = &"neutral"
	_free_arms_until = 0.0
	if is_instance_valid(modifier):
		modifier.reset_state()
	_sync_modifier()

func _sync_modifier() -> void:
	if not is_instance_valid(modifier):
		return
	modifier.seated = seated_pose
	modifier.speak_amount = 1.0 if (conversation and speaking) else 0.0
	modifier.listen_amount = 1.0 if (conversation and listening and not speaking) else 0.0
	modifier.emotion = emotion if conversation else &"neutral"

func update_motion(speed: float, grounded: bool, stance: StringName, backwards: bool) -> void:
	if not is_instance_valid(player) or dying or previewing or not action.is_empty():
		return
	_now += get_physics_process_delta_time()
	seated_pose = stance == &"sit"
	_sync_modifier()
	var body := get_parent() as Node3D
	if body:
		var dyaw := wrapf(body.rotation.y - _last_yaw, -PI, PI)
		_last_yaw = body.rotation.y
		var dt := maxf(get_physics_process_delta_time(), 0.0001)
		_yaw_rate = lerpf(_yaw_rate, absf(dyaw) / dt, 0.25)
		if _turning and _yaw_rate < TURN_RATE_OFF:
			_turning = false
		elif not _turning and _yaw_rate > TURN_RATE_ON:
			_turning = true
	var pick := _choose_base(speed, grounded, stance, backwards)
	var clip: StringName = pick[0]
	var cadence: float = pick[1]
	var fade: float = pick[2]
	var playback_direction := -1.0 if cadence < 0.0 else 1.0
	player.speed_scale = absf(cadence)
	_base_clip = clip
	if current_clip != clip or (player.is_playing() and signf(player.get_playing_speed()) != playback_direction):
		player.play(clip, fade, playback_direction, cadence < 0.0)

## Returns [clip, cadence, fade_seconds].
func _choose_base(speed: float, grounded: bool, stance: StringName, backwards: bool) -> Array:
	var p = profile
	if not grounded:
		return [clip_or_fallback(&"Jump"), 1.0, FADE]
	var free_arms := _now < _free_arms_until
	var idle_clip: StringName = p.free_arms_clip if free_arms else p.idle_clip
	if stance == &"sit":
		var sit_clip: StringName = p.seated_idle_clip
		var cadence := 1.0
		if conversation and speaking:
			sit_clip = p.seated_talk_clip
			cadence = p.talk_speed
		return [clip_or_fallback(sit_clip, &"Sitting_Idle"), cadence, CONV_FADE]
	if stance == &"aim":
		return [clip_or_fallback(&"Pistol_Aim_Neutral"), 1.0, FADE]
	if stance == &"crouch":
		if speed > 0.15:
			return [&"Crouch_Fwd", clampf(speed / 1.05, 0.45, 1.9), FADE]
		return [&"Crouch_Idle", 1.0, FADE]
	if backwards and speed > 0.15:
		return [clip_or_fallback(p.walk_clip, &"Walk"), -clampf(speed / 1.65, 0.45, 2.0), FADE]
	if speed > 4.5:
		return [&"Sprint", speed / 5.6, FADE]
	if speed > 2.35:
		return [&"Jog_Fwd", speed / 3.65, FADE]
	if speed > 0.15:
		return [clip_or_fallback(p.walk_clip, &"Walk"), clampf(speed / 1.65, 0.45, 1.65), FADE]
	if _turning and p.step_turn:
		return [clip_or_fallback(p.walk_clip, &"Walk"), 0.55, CONV_FADE]
	if conversation:
		if speaking:
			var restrained: bool = emotion == &"serious" or emotion == &"suspicious" or emotion == &"concerned"
			var talk: StringName = p.talk_restrained_clip if (restrained or not p.arm_beats_while_speaking) else p.talk_clip
			if free_arms:
				talk = p.free_arms_clip   # arm gestures need an arms-down base
			var cad: float = p.talk_speed * (1.12 if emotion == &"expressive" else 1.0)
			return [clip_or_fallback(talk), cad, CONV_FADE]
		if listening:
			return [clip_or_fallback(p.free_arms_clip if free_arms else p.listen_clip), 1.0, CONV_FADE]
	return [clip_or_fallback(idle_clip), 1.0, CONV_FADE if conversation else FADE]
