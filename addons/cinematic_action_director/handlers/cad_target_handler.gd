class_name CADTargetHandler
extends CADInteractionHandler
## Pure sampled focus/lock evaluator. Provider supplies eligible scalar snapshots;
## no world nodes, physics, Story writes, or widget-driven selection live here.

const MAX_SAMPLE_GAP := 0.1
var provider: Callable
var extent := Vector2(16.0 / 9.0, 1.0)
var cursor := Vector2.ZERO
var focused: StringName
var entries: Array[Dictionary] = []
var _direction := Vector2.ZERO
var _held := false
var _initialised := false

func configure(value: CADInteractionSpec, offered: Array[CADOption]) -> void:
	super.configure(value, offered)
	_refresh()
	cursor = entries[0].position if not entries.is_empty() else extent / 2.0
	_initialised = true
	_focus()

func input(sample: CADInputSample) -> Dictionary:
	if sample.kind == CADInputSample.Kind.DIRECTION:
		_direction = sample.vector if sample.pressed else Vector2.ZERO
		return {}
	if sample.action == spec.target_confirm_action:
		_held = sample.pressed and focused != &""
		if not _held:
			progress = 0.0
		elif spec.target_lock_seconds <= 0.0:
			return _success()
	elif sample.pressed and sample.action in [spec.target_next_action, spec.target_previous_action]:
		_cycle(1 if sample.action == spec.target_next_action else -1)
	elif sample.pressed:
		return wrong()
	return {}

func tick(_elapsed: float, delta: float) -> Dictionary:
	_refresh()
	cursor = (cursor + _direction * spec.target_cursor_speed * minf(delta, MAX_SAMPLE_GAP)).clamp(Vector2.ZERO, extent)
	_focus()
	if delta > MAX_SAMPLE_GAP + 0.0000001:
		# No retroactive lock credit across unseen target/camera motion.
		progress = 0.0
	elif _held and focused != &"" and spec.target_lock_seconds > 0.0:
		progress = minf(1.0, progress + delta / spec.target_lock_seconds)
		if progress >= 1.0 - 0.0000001:
			return _success()
	return {}

func reset_input() -> void:
	_direction = Vector2.ZERO
	_held = false
	progress = 0.0

func view() -> Dictionary:
	return {"cursor": cursor, "focused": focused, "targets": entries.duplicate(true), "radius": spec.target_radius, "extent": extent, "progress": progress}

func _refresh() -> void:
	entries.clear()
	if not provider.is_valid():
		return
	var values: Variant = provider.call()
	if values is not Array:
		return
	var seen: Dictionary = {}
	for value: Variant in values:
		if value is not Dictionary or value.get("position") is not Vector2:
			continue
		var identity: Variant = value.get("id", "")
		if identity is not String and identity is not StringName:
			continue
		var id := StringName(identity)
		var position: Vector2 = value.position
		if not spec.target_options.has(id) or seen.has(id) or not position.is_finite() \
				or position.x < 0.0 or position.y < 0.0 or position.x > extent.x or position.y > extent.y:
			continue
		if not options.any(func(option: CADOption) -> bool: return option.id == spec.target_options[id]):
			continue
		seen[id] = true
		entries.append({"id": id, "position": position, "label": String(value.get("label", id))})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))

func _focus() -> void:
	if not _initialised:
		return
	var candidate: StringName
	var distance := spec.target_radius
	for entry: Dictionary in entries:
		var next_distance := cursor.distance_to(entry.position)
		if next_distance <= distance and (candidate == &"" or next_distance < distance - 0.0000001):
			candidate = entry.id
			distance = next_distance
	if candidate != focused:
		focused = candidate
		_held = false
		progress = 0.0

func _cycle(step: int) -> void:
	if entries.is_empty():
		return
	var index := -1
	for i in entries.size():
		if entries[i].id == focused:
			index = i
	var next := posmod(index + step, entries.size()) if index >= 0 else (0 if step > 0 else entries.size() - 1)
	cursor = entries[next].position
	_held = false
	progress = 0.0
	_focus()

func _success() -> Dictionary:
	return {"grade": &"success", "option_id": spec.target_options[focused], "target_id": focused, "progress": 1.0}
