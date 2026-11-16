class_name CADPlaybackScope
extends RefCounted
## Scales only acquired timeline/actor playback. Weak references permit deletion;
## reference counts handle an actor bound to multiple roles. Audio stays unscaled.

var scale := 1.0
var _records: Dictionary = {}

static func supported(node: Node) -> bool:
	return node is AnimationPlayer or (node.has_method(&"cad_supports_playback_scale") and node.call(&"cad_supports_playback_scale"))

func add(node: Node) -> void:
	if not is_instance_valid(node) or not supported(node):
		return
	var id := node.get_instance_id()
	if _records.has(id):
		_records[id].refs += 1
		return
	var base: float = node.speed_scale if node is AnimationPlayer else node.call(&"cad_playback_speed")
	_records[id] = {"node": weakref(node), "base": base, "refs": 1}
	_apply_speed(node, base * scale)

func remove(node: Node) -> void:
	if not is_instance_valid(node) or not _records.has(node.get_instance_id()):
		return
	var record: Dictionary = _records[node.get_instance_id()]
	record.refs -= 1
	if record.refs <= 0:
		_apply_speed(node, record.base)
		_records.erase(node.get_instance_id())

func set_scale(value: float) -> void:
	scale = value
	for record: Dictionary in _records.values():
		var node: Node = record.node.get_ref()
		if is_instance_valid(node):
			_apply_speed(node, record.base * scale)

func clear() -> void:
	for record: Dictionary in _records.values():
		var node: Node = record.node.get_ref()
		if is_instance_valid(node):
			_apply_speed(node, record.base)
	_records.clear()
	scale = 1.0

func _apply_speed(node: Node, value: float) -> void:
	if node is AnimationPlayer:
		node.speed_scale = value
	else:
		node.call(&"cad_set_playback_speed", value)
