extends Node
## Shared host for every example. It holds no encounter-specific code: the
## stage scene and the sequence resource define the whole encounter.

@export var sequence: CADSequence
@export var flags: Dictionary = {}
@export var autostart := true

var director := CADDirector.new()
var stage: CADStage
var caption: Label

func _ready() -> void:
	DemoInput.ensure()
	stage = $Stage
	add_child(director)
	var layer := CanvasLayer.new()
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.08, 0.1, 0.17, 0.85)
	backdrop.position = Vector2(860, 560)
	backdrop.size = Vector2(390, 110)
	layer.add_child(backdrop)
	var prompt := _label(layer, Vector2(876, 566))
	var bar := ProgressBar.new()
	bar.position = Vector2(876, 648)
	bar.size = Vector2(358, 10)
	bar.step = 0.0
	bar.show_percentage = false
	layer.add_child(bar)
	caption = _label(layer, Vector2(30, 660))
	CADPrompt.bind(director, prompt, bar, backdrop)
	director.finished.connect(_on_finished)
	if autostart:
		start.call_deferred()

func start() -> bool:
	caption.text = ""
	director.flags = flags
	return director.begin(sequence, stage)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"demo_menu"):
		director.cancel()
		get_tree().change_scene_to_file("res://examples/menu.tscn")
	elif event.is_action_pressed(&"demo_replay") and not director.active():
		start()

func _on_finished(outcome: StringName) -> void:
	caption.text = "Outcome: %s     Path: %s     [%s] replay" % [
		outcome, " > ".join(director.trail), CADPrompt.glyph(&"demo_replay", director.using_pad)]

func _label(parent: Node, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override(&"font_size", 22)
	parent.add_child(label)
	return label
