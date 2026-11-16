class_name CADBeat
extends Resource
## One step of an encounter: a timeline, an optional gate and its exits.
## Reactions to success or failure are beats of their own.

@export var id: StringName
## Animation name in the stage's AnimationPlayer. Empty means the host drives
## the beat with CADDirector.marker().
@export var timeline: StringName
@export_range(0.0, 2.0, 0.01) var blend_seconds := 0.0
@export var gate: CADGate
## Where an ungated beat goes when it is done. A beat ID or a terminal outcome.
@export var next: StringName
## Ends the encounter with &"watchdog" if the beat runs this long. Zero derives
## a limit from the timeline and gate; host-driven beats must set it.
@export_range(0.0, 600.0, 0.01) var watchdog_seconds := 0.0

## True when the beat ends without any marker from the host.
func ends_by_itself() -> bool:
	if timeline != &"":
		return true
	return gate != null and gate.open_marker == &"" and gate.cut_on_resolve
