class_name CADContextPredicate
extends Resource
## Typed conditions on authored context. Legacy requires flags may be combined
## with this predicate; first matching CADBranch still wins.

enum Kind { MOMENTUM, INTENT, ACTOR_STATUS, PROP_AVAILABLE }
@export var kind: Kind = Kind.MOMENTUM
@export var subject: StringName
@export var value: StringName
@export_range(0, 100) var minimum := 1
@export var expected := true

func matches(context: CADEncounterContext) -> bool:
	match kind:
		Kind.MOMENTUM: return context.momentum >= minimum
		Kind.INTENT: return context.intent == value
		Kind.ACTOR_STATUS: return context.actor_statuses.get(subject, &"") == value
		Kind.PROP_AVAILABLE: return context.prop_states.get(subject, false) == expected
	return false

func validation_errors(sequence: CADSequence) -> PackedStringArray:
	var errors := PackedStringArray()
	match kind:
		Kind.MOMENTUM:
			if minimum < 0 or minimum > sequence.momentum_limit:
				errors.append("Context momentum threshold is outside the encounter bounds.")
		Kind.INTENT:
			if value not in CADResult.INTENTS:
				errors.append("Context intent is not a supported semantic intention.")
		Kind.ACTOR_STATUS:
			if not sequence.actor_statuses.has(subject) or value == &"":
				errors.append("Context actor status needs a declared role and nonempty status.")
		Kind.PROP_AVAILABLE:
			if not sequence.prop_states.has(subject):
				errors.append("Context prop predicate needs a declared prop ID.")
		_: errors.append("Unsupported context predicate kind.")
	return errors
