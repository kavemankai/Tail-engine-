class_name BarNeonFlicker
extends Node
## Gentle neon flicker. Attach as a child of a Light3D (or set `light`).
## Optionally drives the "flicker" instance uniform on sign/screen geometry.

@export var light: Light3D
@export var geometry: Array[NodePath] = []
@export var enabled := true
@export_range(0.0, 1.0) var depth := 0.10
@export var speed := 7.0
## Average number of brief drop-outs per second.
@export var dropout_rate := 0.03

var _base_energy := 1.0
var _t := 0.0
var _drop := 0.0
var _geos: Array[GeometryInstance3D] = []


func _ready() -> void:
	if light == null and get_parent() is Light3D:
		light = get_parent()
	if light:
		_base_energy = light.light_energy
	for p in geometry:
		var g := get_node_or_null(p)
		if g is GeometryInstance3D:
			_geos.append(g)
	_t = randf() * 100.0


func _process(delta: float) -> void:
	if not enabled:
		_apply(1.0)
		return
	_t += delta * speed
	var v := 1.0 - depth * (0.5 + 0.5 * sin(_t) * sin(_t * 2.31 + 1.7))
	if _drop > 0.0:
		_drop -= delta
		v *= 0.3
	elif randf() < dropout_rate * delta:
		_drop = randf_range(0.04, 0.11)
	_apply(v)


func _apply(v: float) -> void:
	if light:
		light.light_energy = _base_energy * v
	for g in _geos:
		g.set_instance_shader_parameter("flicker", v)
