class_name CADTargetOverlay
extends Control
## Presentation only; the runner remains the sole authority for target outcomes.

var director: CADDirector
var _view: Dictionary = {}

static func install(owner: CADDirector) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 48
	owner.add_child(layer)
	var overlay := CADTargetOverlay.new()
	overlay.director = owner
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

func _process(_delta: float) -> void:
	_view = director.interaction_runner.target_view() if is_instance_valid(director) and director.interaction_runner != null else {}
	visible = not _view.is_empty()
	if visible:
		queue_redraw()

func _draw() -> void:
	if _view.is_empty():
		return
	var height := get_viewport_rect().size.y
	var font := ThemeDB.fallback_font
	for target: Dictionary in _view.targets:
		var at: Vector2 = target.position * height
		var colour := Color(1.0, 0.85, 0.35) if target.id == _view.focused else Color(0.8, 0.85, 0.9)
		draw_circle(at, 5.0, colour)
		draw_string(font, at + Vector2(12, -12), target.label, HORIZONTAL_ALIGNMENT_LEFT, 180, 20, colour)
	var cursor: Vector2 = _view.cursor * height
	var radius: float = _view.radius * height
	draw_arc(cursor, radius, 0.0, TAU, 48, Color(0.9, 0.95, 1.0, 0.8), 2.0, true)
	if _view.progress > 0.0:
		draw_arc(cursor, radius + 5.0, -PI / 2, -PI / 2 + TAU * _view.progress, 48, Color(1.0, 0.85, 0.35), 3.0, true)
