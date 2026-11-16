extends "res://addons/tale_engine/te_placeholder_actor.gd"
## Greybox authored socket for the grab lab; replace with a real BoneAttachment3D.

func _ready() -> void:
	super._ready()
	var socket := Marker3D.new()
	socket.name = "HandSocket"
	socket.position = Vector3(0, 1.0, -0.35)
	add_child(socket)
