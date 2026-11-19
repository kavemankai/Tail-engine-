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
## Item id -> how many are held. Only ids declared in the manifest.
var items: Dictionary = {}
## Earlier episodes of a season: episode id -> { choice id -> option id }.
var history: Dictionary = {}

func reset(new_manifest: TEStoryManifest = null, keep_history := false) -> void:
	if not keep_history:
		history = {}
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
	items = {}

func flag(key: StringName) -> bool:
	return true if vars.get(key, false) else false

func value(key: StringName, fallback: Variant = null) -> Variant:
	return vars.get(key, fallback)

func put(key: StringName, new_value: Variant) -> void:
	if manifest != null and not manifest.has_variable(key):
		# Storing it would make the next save disagree with the manifest.
		TEFault.report("Story: variable '%s' is not declared in the manifest; value ignored." % key)
		return
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
		TEFault.report("Story: choice '%s' / '%s' is not declared in the manifest; choice ignored." % [choice_id, option_id])
		return
	choices[choice_id] = option_id
	if notice != "":
		remembered.emit(notice)

## Give the player an item declared in the manifest.
func give(item: StringName, count: int = 1) -> void:
	if manifest != null and not manifest.has_item(item):
		TEFault.report("Story: item '%s' is not declared in the manifest; not given." % item)
		return
	if count <= 0:
		return
	items[item] = item_count(item) + count
	changed.emit(item, items[item])

## Take items away. False, and nothing changes, if not enough are held.
func take(item: StringName, count: int = 1) -> bool:
	if count <= 0 or item_count(item) < count:
		return false
	var left := item_count(item) - count
	if left > 0:
		items[item] = left
	else:
		items.erase(item)
	changed.emit(item, left)
	return true

func has_item(item: StringName) -> bool:
	return item_count(item) > 0

func item_count(item: StringName) -> int:
	return int(items.get(item, 0))

## The name shown for an item id.
func item_name(item: StringName) -> String:
	return tr(manifest.item_name(item)) if manifest != null else String(item)

## Names of the items held, in the order they were first given.
func inventory() -> PackedStringArray:
	var names := PackedStringArray()
	for item: StringName in items:
		names.append(item_name(item))
	return names

## What the player chose in an earlier episode of this season, or "".
func prior(episode_id: StringName, choice_id: StringName) -> String:
	return String(history.get(episode_id, {}).get(choice_id, ""))

## Copy carried variables into the new episode and remember its predecessor.
func apply_carry(carried_vars: Dictionary, new_history: Dictionary) -> void:
	for key: StringName in carried_vars:
		if manifest == null or manifest.has_variable(key):
			vars[key] = carried_vars[key]
	history = new_history.duplicate(true)

func outcome(step_id: StringName) -> String:
	return String(outcomes.get(step_id, ""))

func result(step_id: StringName, beat_id: StringName) -> String:
	return String(results.get(step_id, {}).get(beat_id, ""))

## One sentence per choice made, in order.
func recap() -> PackedStringArray:
	var lines := PackedStringArray()
	for choice_id: StringName in choices:
		var text := manifest.recap_text(choice_id, choices[choice_id]) if manifest != null else ""
		lines.append(tr(text) if text != "" else "%s: %s" % [choice_id, choices[choice_id]])
	return lines

func to_dict() -> Dictionary:
	var data := {"vars": vars.duplicate(true), "choices": choices.duplicate(true), "outcomes": outcomes.duplicate(true),
		"results": results.duplicate(true), "seen": seen.duplicate(true)}
	if not interactions.is_empty():
		data["interactions"] = interactions.duplicate(true)
	if not items.is_empty():
		data["items"] = items.duplicate(true)
	if not history.is_empty():
		data["history"] = history.duplicate(true)
	return data

func from_dict(data: Dictionary) -> void:
	for field: String in ["vars", "choices", "outcomes", "results", "seen", "interactions", "items"]:
		# A later episode revision may add variables absent in an older save.
		var restored: Dictionary = vars.duplicate(true) if field == "vars" else {}
		var saved: Dictionary = data.get(field, {})
		for key in saved:
			restored[StringName(key)] = saved[key]
		set(field, restored)
	history = {}
	for episode_id in data.get("history", {}):
		history[StringName(episode_id)] = {}
		for choice_id in data["history"][episode_id]:
			history[StringName(episode_id)][StringName(choice_id)] = data["history"][episode_id][choice_id]

func interaction(step_id: StringName, beat_id: StringName) -> Dictionary:
	return interactions.get(step_id, {}).get("results", {}).get(String(beat_id), {}).duplicate(true)

func encounter_context(step_id: StringName) -> Dictionary:
	return interactions.get(step_id, {}).get("context", {}).duplicate(true)

func intent(step_id: StringName) -> String:
	return String(interactions.get(step_id, {}).get("context", {}).get("intent", ""))
