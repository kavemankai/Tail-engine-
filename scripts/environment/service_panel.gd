class_name BarServicePanel
extends Node3D
## Electrical maintenance panel. Presentation only: the hinged cover and the
## amber/green indicators are driven from outside, no gameplay conditions here.
##   $ServicePanel.open_cover()
##   $ServicePanel.set_indicator(&"green", true)

signal cover_toggled(is_open: bool)

@export var amber_on := true:
	set(v):
		amber_on = v
		if is_node_ready(): _refresh()
@export var green_on := false:
	set(v):
		green_on = v
		if is_node_ready(): _refresh()
@export var amber_blink := true
@export var cover_open_angle := 110.0
@export var cover_time := 0.6
@export var on_amber: Material
@export var on_green: Material
@export var off_material: Material

var cover_open := false
var _t := 0.0
var _tween: Tween

@onready var cover_pivot: Node3D = $CoverPivot
@onready var amber_led: GeometryInstance3D = $Indicators/AmberLED
@onready var green_led: GeometryInstance3D = $Indicators/GreenLED
@onready var amber_light: OmniLight3D = $Indicators/AmberLight
@onready var green_light: OmniLight3D = $Indicators/GreenLight


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	if amber_on and amber_blink:
		_t += delta
		var lit := fmod(_t, 1.2) < 0.75
		amber_led.material_override = on_amber if lit else off_material
		amber_light.visible = lit


func open_cover(animate := true) -> void:
	_set_cover(true, animate)


func close_cover(animate := true) -> void:
	_set_cover(false, animate)


func toggle_cover() -> void:
	_set_cover(not cover_open, true)


func set_indicator(which: StringName, on: bool) -> void:
	match which:
		&"amber": amber_on = on
		&"green": green_on = on


func _set_cover(v: bool, animate: bool) -> void:
	cover_open = v
	var target := Vector3(0, deg_to_rad(-cover_open_angle) if v else 0.0, 0)
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(cover_pivot, "rotation", target, cover_time)
	else:
		cover_pivot.rotation = target
	cover_toggled.emit(v)


func _refresh() -> void:
	amber_led.material_override = on_amber if amber_on else off_material
	green_led.material_override = on_green if green_on else off_material
	amber_light.visible = amber_on
	green_light.visible = green_on
