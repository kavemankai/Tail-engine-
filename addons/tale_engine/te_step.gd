class_name TEStep
extends Resource
## One node of the episode graph.

enum Kind { EXPLORE, DIALOGUE, ENCOUNTER, CARD }
enum Card { TITLE, RECAP }

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

@export_group("Dialogue")
@export var dialogue: DialogueResource
@export var cue: String
## Shot to cut to as the conversation starts.
@export var shot: StringName

@export_group("Encounter")
@export var sequence: CADSequence
## Name of the CADStage node in the location.
@export var stage: StringName
## Stage role -> character id.
@export var roles: Dictionary = {}

@export_group("Explore")
@export var hub: StringName

@export_group("Card")
@export var card := Card.TITLE
@export var heading: String
@export_multiline var body: String

## The step to go to after ending with `exit_name`, or &"" if nothing matches.
func next_for(exit_name: StringName) -> StringName:
	for exit in exits:
		if (exit.on == &"*" or exit.on == exit_name) and TECondition.test(exit.when):
			return exit.next
	return &""
