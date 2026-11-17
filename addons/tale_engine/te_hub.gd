class_name TEHub
extends Node3D
## A walk-around area. Its TEHotspot children are live while a step explores it.

signal exited(exit_name: StringName)

## Conversations for this hub's hotspots, one cue each.
@export var dialogue: DialogueResource
@export var camera_offset := Vector3(0, 4.0, 6.5)

var current: TEHotspot
var _player: TEActor
var _controller: TEPlayerController
var _camera: Camera3D
var _zones: Array[Node] = []
var _scope := ""
var _busy := false

func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func activate(player: TEActor, zones: Array[Node], scope: String) -> void:
	_player = player
	_zones = zones
	_scope = scope
	_controller = TEPlayerController.new()
	player.add_child(_controller)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.fov = 55
	_busy = false
	set_process(true)
	set_process_unhandled_input(true)
	_process(0.0)

func deactivate() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	Screen.hint("")
	current = null
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
	_busy = true
	_controller.enabled = false
	Screen.hint("")
	if hotspot.once:
		Story.seen[_seen_id(hotspot)] = true
	var exit_name := hotspot.exit
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

func _process(_delta: float) -> void:
	var zone_camera: Camera3D
	for zone in _zones:
		if zone is TECameraZone and zone.global_position.distance_to(_player.global_position) <= zone.radius:
			zone_camera = zone.camera()
	if not _busy:
		_camera.global_position = _player.global_position + camera_offset
		_camera.look_at(_player.global_position + Vector3.UP)
		var view := zone_camera if zone_camera != null else _camera
		if not view.current:
			view.make_current()
	current = null
	if _busy:
		return
	var best := INF
	for hotspot in hotspots():
		var distance := hotspot.global_position.distance_to(_player.global_position)
		if distance <= hotspot.radius and distance < best and available(hotspot):
			best = distance
			current = hotspot
	Screen.hint("[%s]  %s" % [CADPrompt.glyph(&"te_interact", CADInputDevice.using_pad), tr(current.label)] if current != null else "")

func _unhandled_input(event: InputEvent) -> void:
	if current != null and event.is_action_pressed(&"te_interact"):
		get_viewport().set_input_as_handled()
		use(current)

func _seen_id(hotspot: TEHotspot) -> StringName:
	return StringName("%s/%s" % [_scope, hotspot.name])
