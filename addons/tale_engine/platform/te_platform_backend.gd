class_name TEPlatformBackend
extends RefCounted
## What a store or console layer provides. The local backend works everywhere;
## TESteamBackend talks to GodotSteam when the game ships with it.

## Short name for logs and the debug panel.
func id() -> StringName:
	return &"none"

## Called once at start-up. False if the platform is not usable.
func start() -> bool:
	return true

## Called every frame while running; callbacks are pumped here.
func poll() -> void:
	pass

func unlock(_achievement: StringName) -> bool:
	return false

func is_unlocked(_achievement: StringName) -> bool:
	return false

## Clear one achievement; for testing builds only.
func clear(_achievement: StringName) -> bool:
	return false

## Directory saves are written to. Steam Auto-Cloud is configured to sync it.
func save_directory() -> String:
	return OS.get_user_data_dir()

## The player's name on the platform, or "".
func player_name() -> String:
	return ""

## Language the platform reports, as a Godot locale code, or "".
func language() -> String:
	return ""

func shutdown() -> void:
	pass
