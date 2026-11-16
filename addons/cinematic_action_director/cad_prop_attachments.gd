class_name CADPropAttachments
extends RefCounted
## Props keep their scene parent. A socket-owned RemoteTransform3D follows the
## authored contact offset, so deleting an actor never deletes a held scene prop.

var _records: Dictionary = {}

func attach(prop: Node3D, socket: Node3D) -> bool:
	if not is_instance_valid(prop) or not is_instance_valid(socket) or not prop.is_inside_tree() or not socket.is_inside_tree() \
			or prop == socket or prop.is_ancestor_of(socket):
		return false
	if not _records.has(prop.get_instance_id()):
		_records[prop.get_instance_id()] = {"prop": weakref(prop), "transform": prop.global_transform,
			"freeze": prop.freeze if prop is RigidBody3D else false, "holder": null}
	var record: Dictionary = _records[prop.get_instance_id()]
	_remove_holder(record)
	var holder := Node3D.new()
	socket.add_child(holder)
	holder.global_transform = prop.global_transform
	var remote := RemoteTransform3D.new()
	holder.add_child(remote)
	remote.remote_path = remote.get_path_to(prop)
	record.holder = weakref(holder)
	if prop is RigidBody3D:
		prop.freeze = true
	return true

func detach(prop: Node3D) -> bool:
	if not is_instance_valid(prop) or not _records.has(prop.get_instance_id()):
		return false
	var record: Dictionary = _records[prop.get_instance_id()]
	_remove_holder(record)
	if prop is RigidBody3D:
		prop.freeze = record.freeze
	return true

func release(cancelled := true) -> void:
	for record: Dictionary in _records.values():
		_remove_holder(record)
		var prop: Node3D = record.prop.get_ref()
		if is_instance_valid(prop):
			if cancelled and prop.is_inside_tree():
				prop.global_transform = record.transform
			if prop is RigidBody3D:
				prop.freeze = record.freeze
	_records.clear()

func _remove_holder(record: Dictionary) -> void:
	var holder: Node3D = record.holder.get_ref() if record.holder != null else null
	if is_instance_valid(holder):
		if holder.get_parent() != null:
			holder.get_parent().remove_child(holder)
		holder.queue_free()
	record.holder = null
