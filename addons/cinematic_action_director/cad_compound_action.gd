class_name CADCompoundAction
extends Resource
## Authoring template, not another runtime graph. Build a fresh CADSequence for
## each encounter. Subclasses keep all input evaluation in ordinary CAD gates.

var last_errors := PackedStringArray()

func build() -> CADSequence:
	last_errors = PackedStringArray(["Compound template has no build implementation."])
	return null

func validation_errors() -> PackedStringArray:
	build()
	return last_errors.duplicate()
