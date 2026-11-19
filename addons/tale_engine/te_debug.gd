class_name TEDebug
extends CanvasLayer
## Debug builds only. F3 toggles a panel showing the current step and story
## variables, with buttons to force an exit or jump to any step.

var _panel := PanelContainer.new()
var _box := VBoxContainer.new()
var _info := Label.new()
var _buttons := VBoxContainer.new()
var _shown_step: TEStep

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.position = Vector2(20, 70)
	_panel.add_child(_box)
	_box.add_child(_info)
	var export_button := Button.new()
	export_button.text = "Export QTE trace"
	export_button.focus_mode = Control.FOCUS_NONE
	export_button.pressed.connect(_export_trace)
	_box.add_child(export_button)
	_box.add_child(_buttons)
	add_child(_panel)
	_panel.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_panel.visible = not _panel.visible
		_shown_step = null

func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var lines := PackedStringArray(["Step: %s" % (Flow.step.id if Flow.step != null else &"-")])
	for key: StringName in Story.vars:
		lines.append("%s = %s" % [key, Story.vars[key]])
	for key: StringName in Story.choices:
		lines.append("chose %s: %s" % [key, Story.choices[key]])
	var director := Flow.active_director()
	if director != null:
		lines.append("QTE run %s / visit %s: %s" % [director.run_id(), director.visit(), director.current_beat().id if director.current_beat() != null else &"-"])
		lines.append("Momentum %s/%s | Intent %s" % [director.context.momentum, director.context.limit, director.context.intent])
		lines.append("Actors: " + str(director.context.to_dict().actors).left(100))
		lines.append("Props: " + str(director.context.to_dict().props).left(100))
		if director.interaction_runner != null and director.interaction_runner.active:
			var runner := director.interaction_runner
			lines.append("Input %.2fs left | %.0f%% | controller %s" % [runner.remaining(), runner.progress() * 100, runner.router.controller])
		for event: Dictionary in director.trace.snapshot().events.slice(-5):
			lines.append("%.2f %s %s" % [event.seconds, event.event, event.data.get("beat_id", "")])
	_info.text = "\n".join(lines)
	if Flow.step == _shown_step:
		return
	_shown_step = Flow.step
	for button in _buttons.get_children():
		button.queue_free()
	if Flow.step == null:
		return
	for exit in Flow.step.exits:
		_add("Force exit: %s" % exit.on, Flow.force_exit.bind(exit.on))
	for step in Flow.episode.steps:
		_add("Jump: %s" % step.id, Flow.jump.bind(step.id))

func _add(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_buttons.add_child(button)

func _export_trace() -> void:
	var director := Flow.active_director()
	var data := director.trace.snapshot() if director != null else Flow.latest_trace
	if data.is_empty():
		Screen.notice("No QTE trace recorded yet.")
		return
	var error := CADTrace.save_snapshot(data, "user://cad_trace.json")
	Screen.notice("Saved user://cad_trace.json" if error == OK else "Trace export failed: " + error_string(error))
