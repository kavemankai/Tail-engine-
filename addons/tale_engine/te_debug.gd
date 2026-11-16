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
