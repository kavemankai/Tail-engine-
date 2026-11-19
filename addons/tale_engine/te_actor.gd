class_name TEActor
extends CharacterBody3D
## Contract for a character scene. The engine only calls these methods, so a
## real rig plugs in by extending this and overriding the ones it can do better.
##
## Called by Flow:
##   play_clip(name)        an animation, by its real name (cad_act maps logical names)
##   clip_playing()         true while the last clip is still running
##   speak(talking)         start or stop talking
##   set_mouth_open(0..1)   lip-sync, following voice loudness
##   emote(name)            facial or body emotion, held until the next one
##   gesture(name)          a one-off gesture
##   look_at_point(point)   turn head or body towards a point
##   clear_look()           stop looking at anything in particular

## Blend shape names tried, in order, by the default mouth driver.
const MOUTH_SHAPES: PackedStringArray = ["jawOpen", "mouthOpen", "mouth_open", "viseme_aa", "Mouth_Open", "A"]
## Jaw bone names tried when the meshes have no mouth blend shape.
const JAW_BONES: PackedStringArray = ["jaw", "Jaw", "JawRoot", "CC_Base_JawRoot", "mixamorig:Jaw", "mixamorig_Jaw", "DEF-jaw", "head_jaw"]

## How far the jaw bone opens at full loudness, and around which bone axis.
@export_range(0.0, 45.0) var jaw_open_degrees := 14.0
@export var jaw_axis := Vector3.RIGHT

var character: TECharacter
## Last emotion asked for; &"neutral" by default.
var emotion: StringName = &"neutral"
## Point being looked at, or null.
var look_target: Variant = null

var _mouth_targets: Array = []
var _jaw: Array = []
var _mouth_scanned := false

func setup(new_character: TECharacter) -> void:
	character = new_character

## Called by timelines through CADStage.act(). Maps the logical clip name.
func cad_act(clip: StringName) -> void:
	play_clip(character.clips.get(clip, clip) if character != null else clip)

## Override: play an animation by its real name.
func play_clip(clip: StringName) -> void:
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null and player.has_animation(clip):
		player.play(clip)

## Override: true while the clip asked for last is still playing. Cutscene
## cues that wait for a clip poll this.
func clip_playing() -> bool:
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player == null or not player.is_playing():
		return false
	var animation := player.get_animation(player.current_animation)
	return animation != null and animation.loop_mode == Animation.LOOP_NONE

## Override: start or stop talking.
func speak(_talking: bool) -> void:
	pass

## Override for a facial rig. The default plays the logical clip
## "emote_<name>" if the character maps one.
func emote(name: StringName) -> void:
	emotion = name
	_logical_clip(StringName("emote_%s" % name))

## Override for a gesture library. The default plays the logical clip
## "gesture_<name>" if the character maps one.
func gesture(name: StringName) -> void:
	_logical_clip(StringName("gesture_%s" % name))

## Override for head or eye aim. The default turns the whole body.
func look_at_point(point: Vector3) -> void:
	look_target = point
	face(point)

func clear_look() -> void:
	look_target = null

## Called by the walk-around controller when the player starts or stops
## moving. The default plays the logical clips "walk" and "idle" if mapped;
## rigs that blend on velocity can ignore it.
func locomotion(moving: bool) -> void:
	_logical_clip(&"walk" if moving else &"idle")

func _logical_clip(clip: StringName) -> void:
	if character != null and character.clips.has(clip):
		cad_act(clip)

## Lip-sync hook. `amount` is 0..1 and follows the voice loudness while this
## actor speaks. The default drives a mouth blend shape (see MOUTH_SHAPES) on
## any mesh below this actor, or failing that rotates a jaw bone (JAW_BONES).
## Override it for visemes or sprite mouths.
func set_mouth_open(amount: float) -> void:
	if not _mouth_scanned:
		_scan_mouth()
	amount = clampf(amount, 0.0, 1.0)
	for target in _mouth_targets:
		if is_instance_valid(target[0]):
			target[0].set_blend_shape_value(target[1], amount)
	for target in _jaw:
		var skeleton: Skeleton3D = target[0]
		if is_instance_valid(skeleton):
			var rest: Quaternion = skeleton.get_bone_rest(target[1]).basis.get_rotation_quaternion()
			var open := Quaternion(jaw_axis.normalized(), deg_to_rad(jaw_open_degrees) * amount)
			skeleton.set_bone_pose_rotation(target[1], rest * open)

func _scan_mouth() -> void:
	_mouth_scanned = true
	for node in find_children("*", "MeshInstance3D", true, false):
		for shape_name in MOUTH_SHAPES:
			var index: int = node.find_blend_shape_by_name(shape_name)
			if index >= 0:
				_mouth_targets.append([node, index])
				break
	if not _mouth_targets.is_empty():
		return
	for skeleton: Skeleton3D in find_children("*", "Skeleton3D", true, false):
		for bone_name in JAW_BONES:
			var bone := skeleton.find_bone(bone_name)
			if bone >= 0:
				_jaw.append([skeleton, bone])
				break

func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if not flat.is_equal_approx(global_position):
		look_at(flat)

## AnimationTree adapters override these three hooks to drive a TimeScale node.
func cad_supports_playback_scale() -> bool:
	return find_children("*", "AnimationTree", true, false).is_empty()

func cad_playback_speed() -> float:
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	return player.speed_scale if player != null else 1.0

func cad_set_playback_speed(speed: float) -> void:
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null:
		player.speed_scale = speed
