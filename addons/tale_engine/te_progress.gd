class_name TEProgress
extends RefCounted
## What the player has unlocked across all save slots, in user://progress.cfg.
## Starting a new game replaces a slot, so "which episodes have I reached" is
## kept here instead.

const PATH := "user://progress.cfg"

## The furthest episode index reached in a season (0 is always available).
static func reached(season: TESeason) -> int:
	if season == null:
		return 0
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return 0
	var value: Variant = config.get_value("seasons", _key(season), 0)
	return clampi(value, 0, maxi(season.episodes.size() - 1, 0)) if value is int else 0

## Record that an episode has been reached. Never moves backwards.
static func mark(season: TESeason, index: int) -> void:
	if season == null or index <= reached(season):
		return
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("seasons", _key(season), index)
	config.save(PATH)

static func _key(season: TESeason) -> String:
	return season.resource_path if season.resource_path != "" else season.title
