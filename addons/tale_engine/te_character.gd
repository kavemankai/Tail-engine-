@tool
class_name TECharacter
extends Resource
## A character in the cast. Swap `actor_scene` to replace the placeholder.

@export var id: StringName
@export var display_name: String
@export var colour := Color.WHITE
## A scene whose root extends TEActor. Empty uses the placeholder capsule.
@export var actor_scene: PackedScene
## Logical clip name used in timelines -> this actor's real animation name.
@export var clips: Dictionary = {}
## Folder of voice files named <line id>.ogg or .wav. Missing files are fine.
@export_dir var voice_dir: String
