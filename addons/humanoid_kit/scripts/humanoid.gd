extends CharacterBody3D
## Call the movement API in world space. A zero command brings the body to rest.
signal action_finished(clip: StringName)

@export var female_model := false
@export var tint := Color("#4ab7c8")
@export var model_scene: PackedScene
@export var extra_animations: AnimationLibrary
@export var move_speed := 3.65
@export var acceleration := 13.0
@export var rotation_speed := 11.0
@export var jump_speed := 5.0
@export var auto_face := true
@export var ai_enabled := false

@onready var animator = $Visual
var requested_direction := Vector3.ZERO
var dead := false
var stance: StringName = &"neutral"
var _look_target := Vector3.ZERO
var _look_active := false
var _jump_requested := false
var _air_time := 0.0
var _gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	animator.configure(female_model, tint, model_scene, extra_animations)
	animator.action_finished.connect(_on_action_finished)
	floor_snap_length = 0.25

func set_move_direction(direction: Vector3) -> void:
	requested_direction = Vector3(direction.x, 0, direction.z).limit_length()

func set_move_speed(metres_per_second: float) -> void:
	move_speed = maxf(0.0, metres_per_second)

func set_look_target(world_position: Vector3) -> void:
	_look_target = world_position
	_look_active = true

func clear_look_target() -> void:
	_look_active = false

func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	if not enabled:
		set_move_direction(Vector3.ZERO)

func set_combat_state(state: StringName) -> void:
	if dead or state == stance:
		return
	if stance == &"sit" and state != &"aim":
		play_action(&"stand")
	stance = state
	if state == &"sit":
		play_action(&"sit")
	if state == &"aim":
		# This authored clip settles into an aiming pose.
		play_action(&"Pistol_Aim_Neutral")

func set_appearance(female: bool, colour: Color) -> void:
	female_model = female
	tint = colour
	if is_node_ready():
		animator.configure(female, tint, model_scene, extra_animations)

func play_action(clip: StringName) -> bool:
	return animator.play_action(clip)

func request_jump() -> void:
	_jump_requested = true

func die() -> void:
	if dead:
		return
	dead = true
	velocity.x = 0.0
	velocity.z = 0.0
	set_move_direction(Vector3.ZERO)
	animator.die()

func revive() -> void:
	dead = false
	stance = &"neutral"
	_air_time = 0.0
	velocity = Vector3.ZERO
	animator.reset()

func _physics_process(delta: float) -> void:
	var grounded := is_on_floor()
	var target := requested_direction * move_speed
	if dead or stance == &"sit" or stance == &"aim":
		target = Vector3.ZERO
	elif stance == &"crouch":
		target = target.limit_length(1.25)
	# Full-body one-shots plant the feet. Jump transitions keep momentum.
	if not animator.action.is_empty() and not str(animator.action).begins_with("Jump"):
		target = Vector3.ZERO
	if not dead:
		var facing := requested_direction if auto_face else Vector3.ZERO
		if _look_active:
			facing = _look_target - global_position
			facing.y = 0.0
		if facing.length_squared() > 0.0001:
			rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z),
				1.0 - exp(-rotation_speed * delta))
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(target, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not grounded:
		velocity.y -= _gravity * delta
	elif _jump_requested and not dead and stance != &"sit" and stance != &"aim" and stance != &"crouch":
		velocity.y = jump_speed
		play_action(&"Jump_Start")
	_jump_requested = false
	move_and_slide()
	if is_on_floor():
		if _air_time > 0.10 and not dead:
			play_action(&"Jump_Land")
		_air_time = 0.0
	else:
		_air_time += delta
	var travel := Vector3(velocity.x, 0, velocity.z)
	var backwards := (_look_active or not auto_face) and travel.dot(global_basis.z) < -0.15
	animator.update_motion(travel.length(), _air_time < 0.06, stance, backwards)

func _on_action_finished(clip: StringName) -> void:
	action_finished.emit(clip)
