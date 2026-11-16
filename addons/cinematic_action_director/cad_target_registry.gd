class_name CADTargetRegistry
extends Node
## Scene bindings and eligibility only. Snapshot coordinates are viewport-height
## units, so lock radii and UI circles remain round at different aspect ratios.

@export var targets: Dictionary[StringName, NodePath] = {}
@export var labels: Dictionary[StringName, String] = {}
@export var requires: Dictionary[StringName, StringName] = {}

func target(id: StringName) -> Node3D:
	return get_node_or_null(targets[id]) as Node3D if targets.has(id) else null

func validation_errors(ids: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	for id: StringName in ids:
		if id == &"" or target(id) == null:
			errors.append("Target registry has no Node3D binding for '%s'." % id)
	return errors

func available(id: StringName, flags: Dictionary) -> bool:
	var node := target(id)
	var condition := String(requires.get(id, &""))
	var allowed := condition.is_empty() or (not bool(flags.get(condition.substr(1), false)) if condition.begins_with("!") else bool(flags.get(condition, false)))
	return is_instance_valid(node) and node.is_inside_tree() and node.is_visible_in_tree() and allowed

func snapshot(ids: Array, flags: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not is_inside_tree():
		return found
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return found
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return found
	var sorted := ids.duplicate()
	# StringName ordering uses interned identity; explicit strings give stable UI order.
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id: StringName in sorted:
		var node := target(id)
		var condition := String(requires.get(id, &""))
		var allowed := condition.is_empty() or (not bool(flags.get(condition.substr(1), false)) if condition.begins_with("!") else bool(flags.get(condition, false)))
		if node == null or not node.is_inside_tree() or not node.is_visible_in_tree() or not allowed or camera.is_position_behind(node.global_position):
			continue
		var screen := camera.unproject_position(node.global_position)
		if Rect2(Vector2.ZERO, viewport_size).has_point(screen):
			found.append({"id": id, "label": labels.get(id, String(id)), "position": screen / viewport_size.y})
	return found
