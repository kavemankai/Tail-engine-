class_name TEStoryManifest
extends Resource
## Declares every story variable and major choice in an episode. Names that
## are not declared here are reported, which catches typos in dialogue files.

## Variable name -> starting value.
@export var variables: Dictionary = {}
## Choice id -> { option id -> recap sentence shown at the end of the episode }.
@export var choices: Dictionary = {}

func has_variable(key: StringName) -> bool:
	return variables.has(key) or variables.has(String(key))

func has_option(choice_id: StringName, option_id: StringName) -> bool:
	return recap_text(choice_id, option_id) != ""

func recap_text(choice_id: StringName, option_id: StringName) -> String:
	var options: Dictionary = choices.get(choice_id, choices.get(String(choice_id), {}))
	return options.get(option_id, options.get(String(option_id), ""))
