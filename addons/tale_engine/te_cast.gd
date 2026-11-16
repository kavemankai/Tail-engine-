class_name TECast
extends Resource

@export var characters: Array[TECharacter] = []

func find(id: StringName) -> TECharacter:
	for character in characters:
		if character != null and character.id == id:
			return character
	return null
