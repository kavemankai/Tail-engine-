extends Node
## Autoload "Story". The state every step reads and writes: variables, the
## major choices made, and how each step ended. Dialogue files call it directly:
##   do Story.remember("bartender_friendly", true, "He will remember that.")
##   if Story.flag("stool_noticed")

signal changed(key: StringName, value: Variant)
signal remembered(notice: String)

var manifest: TEStoryManifest
## Variable name -> value. Also handed to CADDirector.flags during encounters.
var vars: Dictionary = {}
## Choice id -> option id, in the order the choices were made.
var choices: Dictionary = {}
## Step id -> the exit that step ended with.
var outcomes: Dictionary = {}
## Step id -> { beat id -> gate result } for encounter steps.
var results: Dictionary = {}
## Ids of one-time things already used, such as hotspots.
var seen: Dictionary = {}
## Optional versioned scalar QTE history, committed only after completed encounters.
var interactions: Dictionary = {}

func reset(new_manifest: TEStoryManifest = null) -> void:
	if new_manifest != null:
		manifest = new_manifest
	vars = {}
	if manifest != null:
		for key in manifest.variables:
			vars[StringName(key)] = manifest.variables[key]
	choices = {}
	outcomes = {}
	results = {}
	seen = {}
	interactions = {}

func flag(key: StringName) -> bool:
	return true if vars.get(key, false) else false

func value(key: StringName, fallback: Variant = null) -> Variant:
	return vars.get(key, fallback)

func put(key: StringName, new_value: Variant) -> void:
	if manifest != null and not manifest.has_variable(key):
		push_error("Story: variable '%s' is not declared in the manifest." % key)
	vars[key] = new_value
	changed.emit(key, new_value)

func add(key: StringName, amount: int = 1) -> void:
	put(key, value(key, 0) + amount)

## Set a value and optionally raise the "they will remember that" banner.
func remember(key: StringName, new_value: Variant = true, notice: String = "") -> void:
	put(key, new_value)
	if notice != "":
		remembered.emit(notice)

## Log a major choice for the end-of-episode recap.
func choose(choice_id: StringName, option_id: StringName, notice: String = "") -> void:
	if manifest != null and not manifest.has_option(choice_id, option_id):
		push_error("Story: choice '%s' / '%s' is not declared in the manifest." % [choice_id, option_id])
	choices[choice_id] = option_id
	if notice != "":
		remembered.emit(notice)

func outcome(step_id: StringName) -> String:
	return String(outcomes.get(step_id, ""))

func result(step_id: StringName, beat_id: StringName) -> String:
	return String(results.get(step_id, {}).get(beat_id, ""))

## One sentence per choice made, in order.
func recap() -> PackedStringArray:
	var lines := PackedStringArray()
	for choice_id: StringName in choices:
		var text := manifest.recap_text(choice_id, choices[choice_id]) if manifest != null else ""
		lines.append(text if text != "" else "%s: %s" % [choice_id, choices[choice_id]])
	return lines

func to_dict() -> Dictionary:
	var data := {"vars": vars.duplicate(true), "choices": choices.duplicate(), "outcomes": outcomes.duplicate(),
		"results": results.duplicate(true), "seen": seen.duplicate()}
	if not interactions.is_empty():
		data["interactions"] = interactions.duplicate(true)
	return data

func from_dict(data: Dictionary) -> void:
	for field: String in ["vars", "choices", "outcomes", "results", "seen", "interactions"]:
		# A later episode revision may add variables absent in an older save.
		var restored: Dictionary = vars.duplicate(true) if field == "vars" else {}
		var saved: Dictionary = data.get(field, {})
		for key in saved:
			restored[StringName(key)] = saved[key]
		set(field, restored)

func interaction(step_id: StringName, beat_id: StringName) -> Dictionary:
	return interactions.get(step_id, {}).get("results", {}).get(String(beat_id), {}).duplicate(true)

func encounter_context(step_id: StringName) -> Dictionary:
	return interactions.get(step_id, {}).get("context", {}).duplicate(true)

func intent(step_id: StringName) -> String:
	return String(interactions.get(step_id, {}).get("context", {}).get("intent", ""))
