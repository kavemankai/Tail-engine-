class_name TEPlayerController
extends Node
## Added to the player's actor for a walk-around step. Moves the parent
## CharacterBody3D on the move_* actions; screen up is world -Z.

var enabled := true
var speed := 3.5

func _physics_process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if enabled else Vector2.ZERO
	body.velocity.x = input.x * speed
	body.velocity.z = input.y * speed
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 * delta
	if input.length() > 0.1:
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-input.x, -input.y), minf(1.0, 12.0 * delta))
	body.move_and_slide()
