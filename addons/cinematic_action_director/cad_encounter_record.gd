class_name CADEncounterRecord
extends RefCounted
## Versioned scalar history, never a mid-contact pose/save-game replacement.
## Optional in v1 Tale saves; legacy checkpoints remain valid without this field.

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.get("schema") != 1 or value.get("results") is not Dictionary \
			or value.get("context") is not Dictionary or value.results.size() > 4096:
		return false
	var context: Dictionary = value.context
	if not _integer(context.get("limit"), 0, 100) or not _integer(context.get("momentum"), 0, int(context.limit)) \
			or not _text(context.get("intent"), true) or (context.intent != "" and StringName(context.intent) not in CADResult.INTENTS) \
			or context.get("actors") is not Dictionary or context.get("props") is not Dictionary:
		return false
	for role in context.actors:
		if not _text(role) or not _text(context.actors[role]):
			return false
	for id in context.props:
		if not _text(id) or context.props[id] is not bool:
			return false
	for id in value.results:
		var result: Variant = value.results[id]
		if not _text(id) or result is not Dictionary or not _result(result) or String(result.beat_id) != String(id):
			return false
	return true

static func _result(result: Dictionary) -> bool:
	for key in ["challenge_id", "beat_id", "grade", "route_id"]:
		if not _text(result.get(key)):
			return false
	for key in ["option_id", "intent_id", "target_id"]:
		if not _text(result.get(key), true):
			return false
	if StringName(result.grade) not in CADResult.GRADES or result.grade == "cancelled" \
			or (result.intent_id != "" and StringName(result.intent_id) not in CADResult.INTENTS):
		return false
	return _integer(result.get("run_id"), 1, 9007199254740991) and _integer(result.get("visit_id"), 1, 9007199254740991) \
		and _integer(result.get("direction"), -1, 7) and _integer(result.get("momentum_delta"), -100, 100) \
		and _number(result.get("progress"), 0, 1) and _number(result.get("timing_error_ms"), -1e9, 1e9)

static func _text(value: Variant, empty := false) -> bool:
	return (value is String or value is StringName) and (empty or not String(value).is_empty()) and String(value).length() <= 128

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and floorf(float(value)) == float(value)
