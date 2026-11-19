class_name TEHotspot
extends Node3D
## Something the player can use in a hub. It runs a cue from the hub's dialogue
## file, ends the step with an exit, or both. A child named "Highlight" is shown
## while the hotspot is on offer.

signal highlighted(on: bool)

## Verb shown in the prompt: "Look", "Talk", "Use".
@export var label := "Look"
@export var radius := 1.6
## The player must face within this many degrees of it. 0 skips the check.
@export_range(0.0, 180.0) var facing_degrees := 0.0
## Cue in the hub's dialogue file. If that conversation calls exit("x"), the
## step ends with "x".
@export var cue: String
## Ends the step with this exit once the cue, if any, has finished.
@export var exit: StringName
## Optional TECondition expression.
@export var when: String
@export var once := false

@export_group("Examine")
## A model shown close up, which the player can turn over, before the cue.
@export var examine_scene: PackedScene
@export_multiline var examine_text := ""

@export_group("Item")
## An item id from the manifest that must be held to use this.
@export var requires_item: StringName
## The item is taken when the hotspot is used.
@export var consumes_item := false
## Cue played instead when the item is not held. Empty does nothing.
@export var missing_item_cue: String

var _lit := false

func set_highlighted(on: bool) -> void:
	if on == _lit:
		return
	_lit = on
	var glow := get_node_or_null(^"Highlight") as Node3D
	if glow != null:
		glow.visible = on
	highlighted.emit(on)

func _ready() -> void:
	var glow := get_node_or_null(^"Highlight") as Node3D
	if glow != null:
		glow.visible = false

## True when the item it needs, if any, is held.
func unlocked() -> bool:
	return requires_item == &"" or Story.has_item(requires_item)

## Within reach and, if it asks for it, in front of `body`.
func reachable(body: Node3D) -> bool:
	var to := global_position - body.global_position
	to.y = 0.0
	if to.length() > radius:
		return false
	if facing_degrees <= 0.0 or to.length_squared() < 0.0001:
		return true
	var forward := -body.global_basis.z
	forward.y = 0.0
	return rad_to_deg(forward.normalized().angle_to(to.normalized())) <= facing_degrees
