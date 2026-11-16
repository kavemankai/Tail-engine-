class_name TECameraZone
extends Node3D
## While the player is within `radius`, a hub uses this zone's Camera3D child
## in place of the follow camera.

@export var radius := 3.0

func camera() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	return null
