@tool
class_name TEStep
extends Resource
## One node of the episode graph.

## Stored in resources as numbers: append new kinds, never reorder.
enum Kind { EXPLORE, DIALOGUE, ENCOUNTER, CARD, CUTSCENE, TIMELINE }
## Stored in resources as numbers: append new cards, never reorder.
enum Card { TITLE, RECAP, CREDITS }
## Exit names that mean the step broke. "*" does not match them; route one
## explicitly (on = "error") only if the story has a real fallback.
const FAULT_EXITS: Array[StringName] = [&"error", &"cancelled"]

@export var id: StringName
@export var kind := Kind.DIALOGUE
## Shown in the checkpoint list.
@export var title: String
## Scene with a TELocation root. Empty keeps the current location.
@export_file("*.tscn") var location: String
## Character id -> mark name. An empty mark leaves the actor where it is.
@export var cast: Dictionary = {}
## Save here, so the player can resume or rewind to this step.
@export var checkpoint := false
@export var exits: Array[TEExit] = []

@export_group("Audio")
## Music from this step on. Empty keeps whatever is playing.
@export var music: AudioStream
## Ambience loop from this step on. Empty keeps whatever is playing.
@export var ambience: AudioStream
## Fade the music out as this step starts.
@export var stop_music := false
## Fade the ambience out as this step starts.
@export var stop_ambience := false
## Crossfade length in seconds for this step's music and ambience changes.
@export_range(0.0, 10.0, 0.1) var audio_fade := 1.5

@export_group("Dialogue")
@export var dialogue: DialogueResource
@export var cue: String
## Shot to cut to as the conversation starts.
@export var shot: StringName

@export_group("Encounter")
@export var sequence: CADSequence
## Optional authoring template. Choose exactly one of sequence or compound.
@export var compound: CADCompoundAction
## Name of the CADStage node in the location.
@export var stage: StringName
## Stage role -> character id.
@export var roles: Dictionary = {}

@export_group("Explore")
@export var hub: StringName

@export_group("Cutscene")
## Played in order. No input; the step ends with exit "end".
@export var cues: Array[TEShotCue] = []

@export_group("Timeline")
## AnimationPlayer in the location, relative to its root.
@export var timeline_player: NodePath = ^"Timeline"
## Animation to play. Its method tracks call a TETimelineCues node for shots,
## clips, voice, sound and captions. The step ends with exit "end".
@export var timeline: StringName
## The player can skip with the advance button (pressed twice).
@export var skippable := true

@export_group("Card")
@export var card := Card.TITLE
@export var heading: String
@export_multiline var body: String

## The step to go to after ending with `exit_name`, or &"" if nothing matches.
func next_for(exit_name: StringName) -> StringName:
	for exit in exits:
		var matches := exit.on == exit_name or (exit.on == &"*" and exit_name not in FAULT_EXITS)
		if matches and TECondition.test(exit.when):
			return exit.next
	return &""

func resolve_sequence() -> CADSequence:
	if sequence != null and compound != null:
		return null
	return compound.build() if compound != null else sequence
