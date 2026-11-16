class_name TEHotspot
extends Node3D
## Something the player can use in a hub. It runs a cue from the hub's dialogue
## file, ends the step with an exit, or both.

## Verb shown in the prompt: "Look", "Talk", "Use".
@export var label := "Look"
@export var radius := 1.6
## Cue in the hub's dialogue file. If that conversation calls exit("x"), the
## step ends with "x".
@export var cue: String
## Ends the step with this exit once the cue, if any, has finished.
@export var exit: StringName
## Optional TECondition expression.
@export var when: String
@export var once := false
