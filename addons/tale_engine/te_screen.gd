extends CanvasLayer
## Autoload "Screen". Everything drawn over the game that is not a
## conversation: fades, the "they will remember that" notice, the interact
## hint, the QTE prompt, title and recap cards, and the pause menu.

signal card_closed

var prompt_label := Label.new()
var prompt_bar := ProgressBar.new()
var prompt_backdrop := ColorRect.new()

var _fade := ColorRect.new()
var _notice := Label.new()
var _hint := Label.new()
var _card := ColorRect.new()
var _card_heading := Label.new()
var _card_body := Label.new()
var _pause := ColorRect.new()
var _notice_left := 0.0
var _card_left := -1.0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_notice.position = Vector2(30, 24)
	_style(_notice, 22)
	add_child(_notice)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position.y -= 150
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_style(_hint, 24)
	add_child(_hint)
	prompt_backdrop.color = Color(0.08, 0.1, 0.17, 0.85)
	prompt_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	prompt_backdrop.offset_left = -420
	prompt_backdrop.offset_top = -280
	prompt_backdrop.offset_right = -30
	prompt_backdrop.offset_bottom = -170
	add_child(prompt_backdrop)
	prompt_label.position = Vector2(16, 8)
	_style(prompt_label, 22)
	prompt_backdrop.add_child(prompt_label)
	prompt_bar.position = Vector2(16, 88)
	prompt_bar.size = Vector2(358, 10)
	prompt_bar.step = 0.0
	prompt_bar.show_percentage = false
	prompt_backdrop.add_child(prompt_bar)
	prompt_backdrop.hide()
	for panel: ColorRect in [_card, _pause, _fade]:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
	_card.color = Color(0.05, 0.06, 0.1, 1)
	_card_heading.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card_heading.position.y = 150
	_card_heading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_style(_card_heading, 44)
	_card.add_child(_card_heading)
	_card_body.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card_body.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_body.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_card_body, 24)
	_card.add_child(_card_body)
	_card.hide()
	_pause.color = Color(0, 0, 0, 0.7)
	var paused := Label.new()
	paused.text = "PAUSED\n\n[%s] resume      [%s] quit to menu" % [CADPrompt.glyph(&"te_pause", false), CADPrompt.glyph(&"te_advance", false)]
	paused.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	paused.grow_horizontal = Control.GROW_DIRECTION_BOTH
	paused.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(paused, 30)
	_pause.add_child(paused)
	_pause.hide()
	_fade.color = Color(0, 0, 0, 0)
	Story.remembered.connect(notice)

func notice(text: String) -> void:
	_notice.text = text
	_notice_left = 3.5

func hint(text: String) -> void:
	_hint.text = text

func fade_out(seconds: float = 0.35) -> void:
	await _fade_to(1.0, seconds)

func fade_in(seconds: float = 0.35) -> void:
	await _fade_to(0.0, seconds)

func is_black() -> bool:
	return _fade.color.a >= 0.99

## Show a full-screen card until the player advances or `hold` seconds pass.
func card(heading: String, body: String, hold: float = 4.0) -> void:
	_card_heading.text = heading
	_card_body.text = body
	_card.show()
	_card_left = hold * Settings.text_hold_scale
	await card_closed
	_card.hide()

func clear() -> void:
	hint("")
	_notice.text = ""
	prompt_backdrop.hide()
	_pause.hide()
	get_tree().paused = false
	if _card_left >= 0.0:
		_card_left = -1.0
		card_closed.emit()

func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice.text = ""
	if _card_left >= 0.0 and not get_tree().paused:
		_card_left -= delta
		if _card_left < 0.0:
			card_closed.emit()

func _input(event: InputEvent) -> void:
	if not Flow.running:
		return
	if event.is_action_pressed(&"te_pause"):
		get_tree().paused = not get_tree().paused
		_pause.visible = get_tree().paused
		get_viewport().set_input_as_handled()
	elif get_tree().paused and event.is_action_pressed(&"te_advance"):
		get_viewport().set_input_as_handled()
		Flow.stop()
	elif _card_left >= 0.0 and event.is_action_pressed(&"te_advance"):
		get_viewport().set_input_as_handled()
		_card_left = -1.0
		card_closed.emit()

func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished

func _style(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.06, 0.1))
	label.add_theme_constant_override(&"outline_size", 6)
