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
var _caption := Label.new()
var _card := ColorRect.new()
var _card_heading := Label.new()
var _card_body := Label.new()
var _pause := ColorRect.new()
var _pause_hint := Label.new()
var _pause_resume: Button
var _settings := ColorRect.new()
var _settings_focus: Control
var _settings_return_focus: Control
var _settings_was_paused := false
var _fade_tween: Tween
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
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.position.y -= 70
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_style(_caption, Settings.subtitle_size)
	add_child(_caption)
	prompt_backdrop.color = Color(0.08, 0.1, 0.17, 0.85)
	prompt_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	prompt_backdrop.offset_left = -420
	prompt_backdrop.offset_top = -280
	prompt_backdrop.offset_right = -30
	prompt_backdrop.offset_bottom = -170
	add_child(prompt_backdrop)
	prompt_label.position = Vector2(16, 8)
	prompt_label.size = Vector2(358, 78)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var pause_box := _centered_box(_pause)
	_pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_pause_hint, 30)
	pause_box.add_child(_pause_hint)
	_pause_resume = _button(pause_box, "Resume", set_paused.bind(false))
	_button(pause_box, "Settings", open_settings)
	_button(pause_box, "Quit to menu", func() -> void: Flow.stop())
	_pause.hide()
	_build_settings()
	# Fades stay above menus, while transparent fades never intercept input.
	move_child(_fade, -1)
	_fade.color = Color(0, 0, 0, 0)
	Story.remembered.connect(notice)
	InputDevice.changed.connect(_refresh_pause)
	_refresh_pause()
	get_tree().root.focus_exited.connect(_focus_lost)

func _centered_box(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -230
	box.offset_right = 230
	box.offset_top = -200
	box.add_theme_constant_override(&"separation", 12)
	parent.add_child(box)
	return box

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override(&"font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build_settings() -> void:
	_settings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.color = Color(0.03, 0.04, 0.07, 0.98)
	_settings.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settings)
	var box := _centered_box(_settings)
	var title := Label.new()
	title.text = "Settings"
	_style(title, 32)
	box.add_child(title)
	_settings_focus = _setting_choice(box, "Subtitles", "subtitle_size", [20, 24, 30, 36], ["Small", "Medium", "Large", "Extra large"])
	_setting_choice(box, "Choice time", "choice_time_scale", [1.0, 1.5, 2.0, 0.0], ["Standard", "1.5×", "2×", "Untimed"])
	_setting_choice(box, "Action prompt time", "qte_window_scale", [1.0, 1.5, 2.0, 3.0], ["Standard", "1.5×", "2×", "3×"])
	_setting_choice(box, "Reading time", "text_hold_scale", [0.75, 1.0, 1.5, 2.0], ["Fast", "Standard", "1.5×", "2×"])
	var volume_label := Label.new()
	volume_label.text = "Master volume"
	_style(volume_label, 22)
	box.add_child(volume_label)
	var volume := HSlider.new()
	volume.name = "MasterVolume"
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = Settings.master_volume
	volume.custom_minimum_size.y = 28
	volume.value_changed.connect(func(value: float) -> void:
		Settings.master_volume = value
		_save_settings())
	box.add_child(volume)
	_button(box, "Back", close_settings)
	_settings.hide()

func _setting_choice(parent: Node, caption: String, key: String, values: Array, labels: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(label, 22)
	row.add_child(label)
	var options := OptionButton.new()
	options.name = key
	options.add_theme_font_size_override(&"font_size", 22)
	for text: String in labels:
		options.add_item(text)
	var selected := values.find(Settings.get(key))
	options.select(maxi(0, selected))
	options.item_selected.connect(func(index: int) -> void:
		Settings.set(key, values[index])
		_save_settings())
	row.add_child(options)
	return options

func _save_settings() -> void:
	if not Settings.save():
		notice("Could not save settings. Check available disk space and permissions.")

func open_settings() -> void:
	if _settings.visible:
		return
	_settings_return_focus = get_viewport().gui_get_focus_owner()
	_settings_was_paused = get_tree().paused
	get_tree().paused = true
	_settings.show()
	_settings_focus.grab_focus()

func close_settings() -> void:
	if not _settings.visible:
		return
	_settings.hide()
	get_tree().paused = _settings_was_paused
	if is_instance_valid(_settings_return_focus) and _settings_return_focus.is_visible_in_tree():
		_settings_return_focus.grab_focus()

func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause.visible = paused
	if paused:
		_pause_resume.grab_focus()
	else:
		_pause_resume.release_focus()

func _refresh_pause(_using_pad: bool = false) -> void:
	_pause_hint.text = "PAUSED\n[%s] resume" % CADPrompt.glyph(&"te_pause", CADInputDevice.using_pad)

func _focus_lost() -> void:
	if Flow.running and not get_tree().paused:
		set_paused(true)

func notice(text: String) -> void:
	_notice.text = text
	_notice_left = 3.5

## Subtitle line for cutscenes. An empty string clears it.
func caption(text: String) -> void:
	_caption.text = text

func hint(text: String) -> void:
	_hint.text = text

func layout_prompt(lines: int) -> void:
	var count := maxi(lines, prompt_label.get_line_count())
	var font := prompt_label.get_theme_font(&"font")
	var line_height := font.get_height(prompt_label.get_theme_font_size(&"font_size"))
	var spacing := prompt_label.get_theme_constant(&"line_spacing")
	var text_height := maxf(28.0 * count, line_height * count + spacing * maxi(0, count - 1))
	var bar_height := maxf(10.0, prompt_bar.get_combined_minimum_size().y)
	var height := maxf(110.0, 8.0 + text_height + 10.0 + bar_height + 12.0)
	prompt_backdrop.offset_top = prompt_backdrop.offset_bottom - height
	prompt_label.size.y = text_height
	prompt_bar.position.y = 8.0 + text_height + 10.0
	prompt_bar.size.y = bar_height

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
	_cancel_fade()
	_fade.color.a = 0.0
	hint("")
	caption("")
	_notice.text = ""
	prompt_backdrop.hide()
	_pause.hide()
	_settings.hide()
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
	if _settings.visible:
		if event.is_action_pressed(&"te_pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close_settings()
		return
	if not Flow.running:
		return
	if event.is_action_pressed(&"te_pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif not get_tree().paused and _card_left >= 0.0 and event.is_action_pressed(&"te_advance"):
		get_viewport().set_input_as_handled()
		_card_left = -1.0
		card_closed.emit()

func _fade_to(alpha: float, seconds: float) -> void:
	_cancel_fade()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_fade_tween = tween
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished
	if _fade_tween == tween:
		_fade_tween = null

func _cancel_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		var previous := _fade_tween
		_fade_tween = null
		previous.kill()
		# Release awaiters as well as the tween; Flow's generation rejects them.
		previous.finished.emit()

func _style(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.06, 0.1))
	label.add_theme_constant_override(&"outline_size", 6)
