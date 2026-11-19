@tool
class_name TEShotCue
extends Resource
## One beat of a cutscene step: where the camera is, who moves, what is said.

## Shots/<name> in the step's location.
@export var shot: StringName
## Seconds to blend from the previous view. 0 is a hard cut.
@export var blend := 0.0
## Seconds before the next cue.
@export var hold := 2.0
## Camera shake amplitude in metres; 0 is none.
@export var shake := 0.0
## Character id who is talking during this cue.
@export var speaker: StringName
@export_multiline var caption := ""
## Character id -> logical clip name, played as the cue starts.
@export var clips: Dictionary = {}
## Spoken by `speaker`; the cue lasts at least as long as the recording.
@export var voice: AudioStream
## A one-shot effect played as the cue starts.
@export var sound: AudioStream
## Character id whose clip must finish before the next cue (after `hold`).
@export var wait_for_clip: StringName
## Character id -> emotion name, applied as the cue starts.
@export var emotes: Dictionary = {}
