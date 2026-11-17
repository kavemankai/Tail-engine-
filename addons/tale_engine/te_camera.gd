class_name TECamera
extends Node
## Camera direction for Flow: hard cuts, timed blends between shots, and shake.
## Added to Flow as `Flow.camera`. Locations still just supply Shots/<name>.

var current: Camera3D
var _rig: Camera3D
var _tween: Tween
var _shake := 0.0
var _shake_left := 0.0
var _shake_total := 0.0

func _process(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var view := get_viewport().get_camera_3d()
	if view == null:
		return
	var strength := _shake * (_shake_left / _shake_total)
	view.h_offset = randf_range(-1.0, 1.0) * strength
	view.v_offset = randf_range(-1.0, 1.0) * strength

## Switch to a camera at once.
func cut_to(camera: Camera3D) -> void:
	_stop_blend()
	_release_current()
	current = camera
	camera.make_current()
	if camera is TEShot:
		camera.begin()

## Move from the view on screen to `camera` over `seconds`, then land on it.
## Falls back to a cut when there is nothing to blend from.
func blend_to(camera: Camera3D, seconds: float) -> void:
	var from := get_viewport().get_camera_3d() if is_inside_tree() else null
	if seconds <= 0.0 or from == null or from == camera:
		cut_to(camera)
		return
	_stop_blend()
	_release_current()
	_rig = Camera3D.new()
	add_child(_rig)
	_rig.global_transform = from.global_transform
	_rig.fov = from.fov
	_rig.make_current()
	current = camera
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_rig, "global_transform", camera.global_transform, seconds)
	_tween.tween_property(_rig, "fov", camera.fov, seconds)
	_tween.chain().tween_callback(_land.bind(camera))

func is_blending() -> bool:
	return _rig != null

## Shake the active view; fades out over `seconds`.
func shake(amplitude: float, seconds: float = 0.4) -> void:
	_shake = amplitude
	_shake_total = maxf(seconds, 0.01)
	_shake_left = _shake_total

## Stop everything and leave cameras where they are.
func stop() -> void:
	_stop_blend()
	_release_current()
	_shake_left = 0.0
	current = null

func _land(camera: Camera3D) -> void:
	_stop_blend()
	if is_instance_valid(camera):
		current = camera
		camera.make_current()
		if camera is TEShot:
			camera.begin()

func _stop_blend() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _rig != null:
		_rig.queue_free()
		_rig = null

func _release_current() -> void:
	if is_instance_valid(current):
		if current is TEShot:
			current.end()
		current.h_offset = 0.0
		current.v_offset = 0.0
