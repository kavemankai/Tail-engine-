class_name TEPlayerController
extends Node
## Added to the player's actor for a walk-around step. Moves the parent
## CharacterBody3D on the move_* actions, relative to the camera on screen.
## After a camera cut the old frame of reference is kept while the stick stays
## held, so a cut never turns the player round mid-walk.

## Horizontal speed below this counts as standing still.
const MOVING := 0.2

var enabled := true
var speed := 3.5
## Radians per second the body turns towards its heading.
var turn_speed := 12.0
## Read input relative to the camera. False makes screen up world -Z.
var camera_relative := true
## Yaw of the frame input is read in; taken from the camera when the stick is
## first pushed.
var reference_yaw := 0.0

var _held := false
var _moving := false

func _physics_process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if enabled else Vector2.ZERO
	if input.length() < 0.1:
		_held = false
	elif not _held:
		_held = true
		var camera := body.get_viewport().get_camera_3d()
		if camera != null:
			reference_yaw = camera_yaw(camera.global_basis)
	var heading := world_direction(input)
	body.velocity.x = heading.x * speed
	body.velocity.z = heading.z * speed
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * delta
	if heading.length() > 0.1:
		body.rotation.y = rotate_toward(body.rotation.y, atan2(-heading.x, -heading.z), turn_speed * delta)
	body.move_and_slide()
	var moving := Vector2(body.velocity.x, body.velocity.z).length() > MOVING
	if moving != _moving:
		_moving = moving
		if body is TEActor:
			body.locomotion(moving)

## Input vector (screen space, up is -y) to a flat world direction.
func world_direction(input: Vector2) -> Vector3:
	var flat := Vector3(input.x, 0.0, input.y)
	return flat.rotated(Vector3.UP, reference_yaw) if camera_relative else flat

## Yaw of a camera's view, ignoring pitch: 0 looks along -Z.
static func camera_yaw(basis: Basis) -> float:
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = basis.y
		forward.y = 0.0
	return atan2(-forward.x, -forward.z)

func _exit_tree() -> void:
	var body := get_parent()
	if _moving and body is TEActor:
		body.locomotion(false)
	_moving = false
