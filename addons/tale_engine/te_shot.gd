class_name TEShot
extends Camera3D
## An authored camera for Shots/<name>. A plain Camera3D also works as a shot;
## this one adds a slow move that plays while it is the active shot, which is
## how a push-in or drift is authored without code.

## Local-space translation applied over `drift_time` seconds.
@export var drift := Vector3.ZERO
## Field-of-view change over `drift_time` seconds.
@export var fov_drift := 0.0
@export var drift_time := 4.0

var _rest := Transform3D.IDENTITY
var _rest_fov := 75.0
var _tween: Tween

func _ready() -> void:
	_rest = transform
	_rest_fov = fov

## Called by TECamera when this shot becomes active.
func begin() -> void:
	end()
	if drift == Vector3.ZERO and is_zero_approx(fov_drift):
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", _rest.origin + _rest.basis * drift, drift_time)
	if not is_zero_approx(fov_drift):
		_tween.tween_property(self, "fov", _rest_fov + fov_drift, drift_time)

## Called when another shot takes over. Restores the rest pose.
func end() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	transform = _rest
	fov = _rest_fov
