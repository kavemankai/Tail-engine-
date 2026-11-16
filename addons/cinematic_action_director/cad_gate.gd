class_name CADGate
extends Resource
## A timed input window with one or more options. One option is a plain QTE,
## several make a choice. The result is the chosen option's ID or &"timeout".

@export var options: Array[CADOption] = []
## Opt-in v2 evaluator. Null preserves the original press/hold/buffer semantics.
@export var interaction: CADInteractionSpec
@export_range(0.05, 60.0, 0.01) var window_seconds := 1.2
## A beat ID or a terminal outcome.
@export var timeout_next: StringName
## Timeline marker that opens the gate. Empty opens it as the beat starts.
@export var open_marker: StringName
## True leaves the beat the moment the gate resolves. False lets the timeline
## finish first, so the branch starts from the timeline's last pose.
@export var cut_on_resolve := true
## A press this soon before the gate opens still counts.
@export_range(0.0, 1.0, 0.01) var buffer_seconds := 0.15
