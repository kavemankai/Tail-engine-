class_name TEExit
extends Resource
## One way out of a step. The first exit that matches wins.

## The exit or outcome name the step ended with, or "*" for any.
@export var on: StringName = &"*"
## Optional TECondition expression.
@export var when: String
## A step id, or "END".
@export var next: StringName
