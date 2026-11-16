class_name TEActor
extends CharacterBody3D
## Contract for a character scene. The engine only calls these methods, so a
## real rig plugs in by extending this and overriding play_clip() and speak().

var character: TECharacter

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

func face(point: Vector3) -> void:
	var flat := Vector3(point.x, global_position.y, point.z)
	if not flat.is_equal_approx(global_position):
		look_at(flat)
