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

func find(step_id: StringName) -> TEStep:
	for step in steps:
		if step != null and step.id == step_id:
			return step
	return null
