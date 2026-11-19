class_name TEHub
extends Node3D
## A walk-around area. Its TEHotspot children are live while a step explores it.

signal exited(exit_name: StringName)

## Conversations for this hub's hotspots, one cue each.
@export var dialogue: DialogueResource
@export var camera_offset := Vector3(0, 4.0, 6.5)
## How quickly the follow camera catches up; higher is tighter. 0 snaps.
@export_range(0.0, 30.0) var camera_smoothing := 8.0
## Pull the camera in front of walls between it and the player.
@export var camera_collision := true
## Collision layers that block the camera.
@export_flags_3d_physics var camera_mask := 1
## Height above the player's feet the camera looks at.
@export var camera_focus_height := 1.0
## Movement follows the camera; off makes screen up world -Z.
@export var camera_relative_movement := true

var current: TEHotspot
var _player: TEActor
var _controller: TEPlayerController
var _camera: Camera3D
var _zones: Array[Node] = []
var _scope := ""
var _busy := false
var _snap := true
var _hint := ""

func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func activate(player: TEActor, zones: Array[Node], scope: String) -> void:
	_player = player
	_zones = zones
	_scope = scope
	_controller = TEPlayerController.new()
	_controller.camera_relative = camera_relative_movement
	player.add_child(_controller)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.fov = 55
	_busy = false
	_snap = true
	_hint = ""
	set_process(true)
	set_process_unhandled_input(true)
	_process(0.0)

func deactivate() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	_hint = ""
	Screen.hint("")
	_offer(null)
	for node: Node in [_controller, _camera]:
		if is_instance_valid(node):
			if node is TEPlayerController:
				node.enabled = false
				node.set_physics_process(false)
			node.queue_free()
	_controller = null
	_camera = null
	_busy = false

func cancel() -> void:
	var active := is_processing()
	deactivate()
	if active:
		exited.emit(&"cancelled")

func hotspots() -> Array[TEHotspot]:
	var found: Array[TEHotspot] = []
	for child in get_children():
		if child is TEHotspot:
			found.append(child)
	return found

func available(hotspot: TEHotspot) -> bool:
	return not (hotspot.once and Story.seen.has(_seen_id(hotspot))) and TECondition.test(hotspot.when)

## Use a hotspot now, as the interact button would.
func use(hotspot: TEHotspot) -> void:
	if _busy or not available(hotspot):
		return
	if not hotspot.unlocked():
		if hotspot.missing_item_cue != "" and dialogue != null:
			_busy = true
			_controller.enabled = false
			_set_hint("")
			await Flow.converse(dialogue, hotspot.missing_item_cue)
			if is_processing():
				_busy = false
				_controller.enabled = true
		return
	_busy = true
	_controller.enabled = false
	_set_hint("")
	_offer(null)
	if hotspot.once:
		Story.seen[_seen_id(hotspot)] = true
	if hotspot.consumes_item and hotspot.requires_item != &"":
		Story.take(hotspot.requires_item)
	var exit_name := hotspot.exit
	if hotspot.examine_scene != null:
		var view := TEExamine.open(self, hotspot.examine_scene, hotspot.examine_text)
		await view.closed
		if not is_processing():
			return
	if hotspot.cue != "":
		var said: StringName = await Flow.converse(dialogue, hotspot.cue)
		if said != TEBalloon.DEFAULT_EXIT:
			exit_name = said
	if not is_processing():
		return
	_busy = false
	_controller.enabled = true
	if exit_name != &"":
		exited.emit(exit_name)

func _process(delta: float) -> void:
	var zone_camera: Camera3D
	for zone in _zones:
		if zone is TECameraZone and zone.global_position.distance_to(_player.global_position) <= zone.radius:
			zone_camera = zone.camera()
	if not _busy:
		_follow(delta)
		var view := zone_camera if zone_camera != null else _camera
		if not view.current:
			view.make_current()
	if _busy:
		return
	var best := INF
	var found: TEHotspot = null
	for hotspot in hotspots():
		var distance := hotspot.global_position.distance_to(_player.global_position)
		if distance < best and hotspot.reachable(_player) and available(hotspot):
			best = distance
			found = hotspot
	_offer(found)
	_set_hint(_hint_for(found))

## Move the follow camera towards its place behind the player, easing unless
## snapping, and in front of anything solid between the two.
func _follow(delta: float) -> void:
	var focus := _player.global_position + Vector3.UP * camera_focus_height
	var desired := _player.global_position + camera_offset
	if camera_collision and _player.is_inside_tree():
		desired = _clear_view(focus, desired)
	if _snap or camera_smoothing <= 0.0:
		_camera.global_position = desired
		_snap = false
	else:
		_camera.global_position = _camera.global_position.lerp(desired, 1.0 - exp(-camera_smoothing * delta))
	if not _camera.global_position.is_equal_approx(focus):
		_camera.look_at(focus)

func _clear_view(focus: Vector3, desired: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(focus, desired, camera_mask, [_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var point: Vector3 = hit["position"]
	return point + (focus - point).normalized() * 0.3

func _offer(hotspot: TEHotspot) -> void:
	if current == hotspot:
		return
	if is_instance_valid(current):
		current.set_highlighted(false)
	current = hotspot
	if current != null:
		current.set_highlighted(true)

func _hint_for(hotspot: TEHotspot) -> String:
	if hotspot == null:
		return ""
	var text := "[%s]  %s" % [CADPrompt.glyph(&"te_interact", CADInputDevice.using_pad), tr(hotspot.label)]
	if not hotspot.unlocked():
		text += "  ·  " + tr("Needs %s") % Story.item_name(hotspot.requires_item)
	return text

## Write the hint only when it changes.
func _set_hint(text: String) -> void:
	if text != _hint:
		_hint = text
		Screen.hint(text)

func _unhandled_input(event: InputEvent) -> void:
	if current != null and event.is_action_pressed(&"te_interact"):
		get_viewport().set_input_as_handled()
		use(current)

func _seen_id(hotspot: TEHotspot) -> StringName:
	return StringName("%s/%s" % [_scope, hotspot.name])
