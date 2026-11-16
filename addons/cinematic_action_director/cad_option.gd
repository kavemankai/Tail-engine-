class_name CADOption
extends Resource
## One way through a gate: an InputMap action and where it leads.

@export var id: StringName
@export var action: StringName
@export var label: String
## Zero means a press. Above zero the action must be held this long.
@export_range(0.0, 10.0, 0.01) var hold_seconds := 0.0
## Optional key in CADDirector.flags. The option is offered only when it is truthy.
@export var requires: StringName
## A beat ID or a terminal outcome.
@export var next: StringName
