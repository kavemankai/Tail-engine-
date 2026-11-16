extends "humanoid.gd"

const Bindings := preload("input_bindings.gd")
@export var capture_mouse_on_ready := true
@export var camera_distance := 5.4
var controls_enabled := true
var _yaw := 0.0
var _pitch := -0.22
var _aim_held := false
var _camera_collision: RID

@onready var orbit: Node3D = $Orbit
@onready var pivot: Node3D = $Orbit/Pitch
@onready var camera: Camera3D = $Orbit/Pitch/Camera3D

func _ready() -> void:
	super._ready()
	Bindings.install()
	_camera_collision = get_rid()
	if capture_mouse_on_ready and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -0.95, 0.40)

func _physics_process(delta: float) -> void:
	if controls_enabled:
		_read_controls(delta)
	super._physics_process(delta)
	orbit.global_position = global_position + Vector3.UP * 1.45
	orbit.rotation.y = _yaw
	pivot.rotation.x = _pitch
	_place_camera()

func _read_controls(delta: float) -> void:
	var stick := Input.get_vector("hk_camera_left", "hk_camera_right", "hk_camera_up", "hk_camera_down")
	_yaw -= stick.x * 2.4 * delta
	_pitch = clampf(_pitch - stick.y * 2.0 * delta, -0.95, 0.40)
	var move := Input.get_vector("hk_left", "hk_right", "hk_forward", "hk_back")
	set_move_direction(Vector3(move.x, 0, move.y).rotated(Vector3.UP, _yaw))
	var speed := 3.65
	if Input.is_action_pressed("hk_walk"):
		speed = 1.65
	if Input.is_action_pressed("hk_sprint"):
		speed = 5.6
	set_move_speed(speed)
	if Input.is_action_just_pressed("hk_jump"):
		request_jump()
	var aim_input := Input.is_action_pressed("hk_aim")
	if aim_input:
		if not _aim_held:
			set_combat_state(&"aim")
		set_look_target(global_position + Vector3.FORWARD.rotated(Vector3.UP, _yaw))
	else:
		if _aim_held and stance == &"aim":
			set_combat_state(&"neutral")
			clear_look_target()
		if Input.is_action_just_pressed("hk_crouch"):
			set_combat_state(&"neutral" if stance == &"crouch" else &"crouch")
	_aim_held = aim_input
	if Input.is_action_just_pressed("hk_fire") or (stance == &"aim" and Input.is_action_just_pressed("hk_attack")):
		play_action(&"fire")
	elif Input.is_action_just_pressed("hk_attack"):
		play_action(&"attack")
	elif Input.is_action_just_pressed("hk_melee"):
		play_action(&"melee")
	elif Input.is_action_just_pressed("hk_roll"):
		play_action(&"roll")
	elif Input.is_action_just_pressed("hk_interact"):
		play_action(&"interact")

func _place_camera() -> void:
	var target := pivot.to_global(Vector3(0, 0, camera_distance))
	var query := PhysicsRayQueryParameters3D.create(pivot.global_position, target, 1, [_camera_collision])
	var contact := get_world_3d().direct_space_state.intersect_ray(query)
	camera.position.z = camera_distance
	if not contact.is_empty():
		camera.position.z = maxf(0.4, pivot.global_position.distance_to(contact.position) - 0.22)
