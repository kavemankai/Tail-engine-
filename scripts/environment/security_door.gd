class_name BarSecurityDoor
extends Node3D
## Sliding security door for the restricted corridor.
## Pure presentation: no access logic. Call open()/close()/set_locked() from your game.
##   $RestrictedDoor.open()          # slides the leaf into the wall pocket
##   $RestrictedDoor.set_locked(false) # switches indicators to green

signal door_opened
signal door_closed
signal lock_state_changed(locked: bool)

@export var locked := true:
	set(v):
		locked = v
		if is_node_ready():
			_update_indicators()
			lock_state_changed.emit(locked)
@export var start_open := false
## Local -Z distance the leaf slides when open (metres).
@export var slide_distance := 1.22
@export var open_time := 0.85
@export var locked_material: Material
@export var unlocked_material: Material
@export var locked_light_color := Color(1.0, 0.12, 0.08)
@export var unlocked_light_color := Color(0.15, 1.0, 0.35)

var is_open := false
var _tween: Tween

@onready var leaf: Node3D = $Leaf


func _ready() -> void:
	_update_indicators()
	if start_open:
		set_open(true, false)


func open(animate := true) -> void:
	set_open(true, animate)


func close(animate := true) -> void:
	set_open(false, animate)


func toggle(animate := true) -> void:
	set_open(not is_open, animate)


func set_open(value: bool, animate := true) -> void:
	is_open = value
	var target := Vector3(0, 0, -slide_distance if value else 0.0)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(leaf, "position", target, open_time)
		_tween.tween_callback(_emit_state)
	else:
		leaf.position = target
		_emit_state()


func set_locked(value: bool) -> void:
	locked = value


func _emit_state() -> void:
	if is_open:
		door_opened.emit()
	else:
		door_closed.emit()


func _update_indicators() -> void:
	for n in find_children("*", "GeometryInstance3D", true, false):
		if n.is_in_group("door_indicator"):
			n.material_override = locked_material if locked else unlocked_material
	for n in find_children("*", "Light3D", true, false):
		if n.is_in_group("door_indicator"):
			n.light_color = locked_light_color if locked else unlocked_light_color
