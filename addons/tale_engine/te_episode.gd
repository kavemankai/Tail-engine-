@tool
class_name TEEpisode
extends Resource

@export var id: StringName
@export var title: String
@export var manifest: TEStoryManifest
@export var cast: TECast
## Character the player controls in walk-around steps.
@export var player: StringName
@export var entry: StringName
@export var steps: Array[TEStep] = []
## Old step id -> new id. Add an entry when a patch renames a checkpoint step,
## so saves made before the patch resume at the right place.
@export var renamed_steps: Dictionary = {}
## Where the editor's graph panel last placed each step: id -> Vector2.
@export var editor_positions: Dictionary = {}

func find(step_id: StringName) -> TEStep:
	for step in steps:
		if step != null and step.id == step_id:
			return step
	return null
