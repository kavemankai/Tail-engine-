class_name TEActor
extends CharacterBody3D
## Contract for a character scene. The engine only calls these methods, so a
## real rig plugs in by extending this and overriding play_clip() and speak().

## Blend shape names tried, in order, by the default mouth driver.
const MOUTH_SHAPES: PackedStringArray = ["jawOpen", "mouthOpen", "mouth_open", "viseme_aa", "Mouth_Open", "A"]

var character: TECharacter

var _mouth_targets: Array = []
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

## Override: start or stop talking.
func speak(_talking: bool) -> void:
	pass

## Lip-sync hook. `amount` is 0..1 and follows the voice loudness while this
## actor speaks. The default drives a mouth blend shape (see MOUTH_SHAPES) on any
## mesh below this actor; override it for jaw bones, visemes or sprite mouths.
func set_mouth_open(amount: float) -> void:
	if not _mouth_scanned:
		_mouth_scanned = true
		for node in find_children("*", "MeshInstance3D", true, false):
			for shape_name in MOUTH_SHAPES:
				var index: int = node.find_blend_shape_by_name(shape_name)
				if index >= 0:
					_mouth_targets.append([node, index])
					break
	for target in _mouth_targets:
		if is_instance_valid(target[0]):
			target[0].set_blend_shape_value(target[1], clampf(amount, 0.0, 1.0))

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
