class_name TEExamine
extends CanvasLayer
## Close-up of an object the player can turn over: the model in its own small
## world, a line of text, and a prompt to put it down. Opened by a hotspot
## with an examine_scene; closes on advance (Escape still pauses).

signal closed

## Degrees per second the model turns at full stick.
const TURN_SPEED := 120.0
const DISTANCE := 1.6

var model: Node3D
var _view := SubViewport.new()
var _pivot := Node3D.new()
var _text := Label.new()
var _prompt := Label.new()
var _done := false

## Show `scene` with `text` under it. Await `closed`.
static func open(parent: Node, scene: PackedScene, text: String) -> TEExamine:
	var examine := TEExamine.new()
	examine.setup(scene, text)
	parent.add_child(examine)
	return examine

func setup(scene: PackedScene, text: String) -> void:
	var instance := scene.instantiate() if scene != null else null
	model = instance as Node3D
	if instance != null and model == null:
		instance.free()
	_text.text = tr(text) if text != "" else ""

func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.04, 0.92)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_bottom = -140
	add_child(frame)
	_view.own_world_3d = true
	_view.transparent_bg = true
	frame.add_child(_view)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.6, 0.0)
	_view.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, DISTANCE)
	camera.fov = 40
	_view.add_child(camera)
	camera.make_current()
	_view.add_child(_pivot)
	if model != null:
		_pivot.add_child(model)
	_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_text.offset_top = -130
	_text.offset_bottom = -70
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override(&"font_size", Settings.subtitle_size)
	add_child(_text)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -60
	_prompt.offset_bottom = -20
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override(&"font_size", 20)
	add_child(_prompt)
	_refresh_prompt()
	InputDevice.changed.connect(_refresh_prompt)

func _refresh_prompt(_using_pad: bool = false) -> void:
	_prompt.text = tr("[%s] Put it down    Move to turn it") % CADPrompt.glyph(&"te_advance", CADInputDevice.using_pad)

func _process(delta: float) -> void:
	var turn := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	_pivot.rotate_y(deg_to_rad(turn.x * TURN_SPEED * delta))
	_pivot.rotate_object_local(Vector3.RIGHT, deg_to_rad(turn.y * TURN_SPEED * delta))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"te_advance"):
		get_viewport().set_input_as_handled()
		close()

## Turned so far, as a basis; tests read it.
func orientation() -> Basis:
	return _pivot.basis

func close() -> void:
	if _done:
		return
	_done = true
	closed.emit()
	queue_free()
