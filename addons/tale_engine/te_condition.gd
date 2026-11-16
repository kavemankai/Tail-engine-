class_name TECondition
extends RefCounted
## One condition language for the whole engine: a Godot expression over the
## story variables, with Story's methods callable.
##   "bartender_friendly and not insulted_stranger"
##   "outcome('bar_fight') == 'won'"

static func test(text: String) -> bool:
	if text.strip_edges() == "":
		return true
	var outcome := _evaluate(text, Story.vars)
	if outcome[0] != "":
		push_error("Condition '%s': %s" % [text, outcome[0]])
		return false
	return true if outcome[1] else false

## Empty when the condition parses and runs against the given variables.
static func error(text: String, variables: Dictionary) -> String:
	return "" if text.strip_edges() == "" else _evaluate(text, variables)[0]

static func _evaluate(text: String, variables: Dictionary) -> Array:
	var expression := Expression.new()
	var names := PackedStringArray()
	for key in variables:
		names.append(String(key))
	if expression.parse(text, names) != OK:
		return [expression.get_error_text(), null]
	var value: Variant = expression.execute(variables.values(), Story, false)
	if expression.has_execute_failed():
		return [expression.get_error_text(), null]
	return ["", value]
