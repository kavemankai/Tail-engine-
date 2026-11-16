class_name CADBark
extends Resource
## Brief action dialogue cue. Input remains with the current CAD gate.

@export var id: StringName
@export var speaker: StringName
@export_multiline var text: String
@export_range(0.05, 60.0) var seconds := 2.0
@export var voice: AudioStream
@export_range(0, 90) var priority := 50

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or speaker == &"" or text.strip_edges().is_empty() or text.length() > 160:
		errors.append("Bark needs an ID, speaker role and 1–160 characters of text.")
	if not is_finite(seconds) or seconds < 0.05 or seconds > 60.0 or priority < 0 or priority > 90:
		errors.append("Bark needs finite duration in [0.05, 60] and priority in [0, 90].")
	return errors
