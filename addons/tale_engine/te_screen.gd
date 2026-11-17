extends CanvasLayer
## Autoload "Screen". Everything drawn over the game that is not a
## conversation: fades, the "they will remember that" notice, the interact
## hint, the QTE prompt, title and recap cards, and the pause menu.

signal card_closed

const QUIT_LABEL := "Quit to menu"
const QUIT_CONFIRM := "Quit? Progress since the last checkpoint is lost."

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
var _pause_quit: Button
var _settings := ColorRect.new()
var _settings_focus: Control
var _settings_return_focus: Control
var _settings_was_paused := false
## Rebinding rows: [action, is_pad, button].
var _binding_buttons: Array = []
## Non-empty while the settings menu waits for an input to bind.
var _capture: Dictionary = {}
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
	_pause_quit = _button(pause_box, QUIT_LABEL, _quit_pressed)
	_pause.hide()
	_build_settings()
	_settings.hide()
	# Fades stay above menus, while transparent fades never intercept input.
	move_child(_fade, -1)
	_fade.color = Color(0, 0, 0, 0)
	Story.remembered.connect(notice)
	InputDevice.changed.connect(_refresh_pause)
	_refresh_pause()
	get_tree().root.focus_exited.connect(_focus_lost)
	Settings.changed.connect(_restyle)
	_restyle()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

## Follow options that change how this layer looks, without a restart.
func _restyle() -> void:
	_caption.add_theme_font_size_override(&"font_size", Settings.subtitle_size)
	_caption.visible = Settings.subtitles
	_refresh_pause()
	if _settings.visible:
		_refresh_bindings()

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
	if _settings.get_parent() == null:
		add_child(_settings)
	_binding_buttons.clear()
	# One scrolling column: it follows focus, so a controller reaches every row.
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 30
	scroll.offset_bottom = -30
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 560
	box.add_theme_constant_override(&"separation", 10)
	centre.add_child(box)
	_heading(box, "Settings", 32)

	_heading(box, "Subtitles")
	_settings_focus = _setting_choice(box, "Size", "subtitle_size", [20, 24, 30, 36], ["Small", "Medium", "Large", "Extra large"])
	_setting_toggle(box, "Show subtitles", "subtitles")
	_setting_toggle(box, "Background behind subtitles", "subtitle_background")
	_setting_choice(box, "Reading time", "text_hold_scale", [0.75, 1.0, 1.5, 2.0], ["Fast", "Standard", "1.5×", "2×"])

	_heading(box, "Assistance")
	_setting_choice(box, "Choice time", "choice_time_scale", [1.0, 1.5, 2.0, 0.0], ["Standard", "1.5×", "2×", "Untimed"])
	_setting_choice(box, "Action prompt time", "qte_window_scale", [1.0, 1.5, 2.0, 3.0], ["Standard", "1.5×", "2×", "3×"])
	_setting_toggle(box, "Highlight and confirm responses", "choice_highlight")

	_heading(box, "Audio")
	_setting_slider(box, "Master volume", "master_volume", "MasterVolume")
	_setting_slider(box, "Music", "music_volume", "MusicVolume")
	_setting_slider(box, "Effects", "sfx_volume", "SfxVolume")
	_setting_slider(box, "Voices", "voice_volume", "VoiceVolume")

	_heading(box, "Display")
	_setting_toggle(box, "Fullscreen", "fullscreen")
	_setting_toggle(box, "Vertical sync", "vsync")
	_setting_choice(box, "3D resolution", "render_scale", [1.0, 0.85, 0.7, 0.5], ["Full", "High", "Medium", "Low"])
	var locales := TranslationServer.get_loaded_locales()
	if locales.size() > 1:
		var codes: Array = [""]
		var names: Array = ["System"]
		for code in locales:
			codes.append(code)
			names.append(TranslationServer.get_locale_name(code))
		_setting_choice(box, "Language", "language", codes, names)

	_heading(box, "Controls")
	_setting_choice(box, "Controller button names", "prompt_style", ["", "xbox", "playstation", "nintendo"], ["Automatic", "Xbox", "PlayStation", "Nintendo"])
	for action in TEBindings.actions():
		var row := HBoxContainer.new()
		row.name = "bind_" + String(action)
		box.add_child(row)
		var label := Label.new()
		label.text = TEBindings.label(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style(label, 20)
		row.add_child(label)
		for pad: bool in [false, true]:
			var button := Button.new()
			button.name = "pad" if pad else "keys"
			button.custom_minimum_size.x = 150
			button.add_theme_font_size_override(&"font_size", 20)
			button.pressed.connect(_begin_capture.bind(action, pad, button))
			row.add_child(button)
			_binding_buttons.append([action, pad, button])
	_refresh_bindings()
	var reset := _button(box, "Reset everything to defaults", _reset_settings)
	reset.name = "Reset"
	_button(box, "Back", close_settings).name = "Back"

func _heading(parent: Node, text: String, size := 26) -> void:
	var label := Label.new()
	label.text = text
	_style(label, size)
	parent.add_child(label)

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

func _setting_toggle(parent: Node, caption: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.name = key
	toggle.text = caption
	toggle.add_theme_font_size_override(&"font_size", 22)
	toggle.button_pressed = Settings.get(key)
	toggle.toggled.connect(func(on: bool) -> void:
		Settings.set(key, on)
		_save_settings())
	parent.add_child(toggle)
	return toggle

func _setting_slider(parent: Node, caption: String, key: String, node_name: String) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 200
	_style(label, 22)
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = node_name
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get(key)
	slider.custom_minimum_size.y = 28
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set(key, value)
		_save_settings())
	row.add_child(slider)
	return slider

## Wait for the next key (or controller input) and bind it to `action`.
func _begin_capture(action: StringName, pad: bool, button: Button) -> void:
	_capture = {"action": action, "pad": pad}
	button.text = "Press a button…" if pad else "Press a key…"

func _capture_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_capture = {}
		_refresh_bindings()
		return
	var wanted: bool = _capture["pad"]
	if not TEBindings.bindable(event) or TEBindings.is_pad(event) != wanted or event is InputEventMouseButton:
		return
	var swapped := TEBindings.rebind(_capture["action"], event)
	_capture = {}
	_save_settings()
	_refresh_bindings()
	if swapped != &"":
		notice("%s now uses the previous binding." % TEBindings.label(swapped))

func _refresh_bindings() -> void:
	for entry: Array in _binding_buttons:
		var event := TEBindings.current(entry[0], entry[1])
		var button: Button = entry[2]
		if is_instance_valid(button):
			button.text = CADPrompt.event_name(event) if event != null else "Unbound"

func _reset_settings() -> void:
	Settings.reset()
	_save_settings()
	var was_visible := _settings.visible
	for child in _settings.get_children():
		_settings.remove_child(child)
		child.queue_free()
	_build_settings()
	_settings.visible = was_visible
	if was_visible:
		_settings_focus.grab_focus()

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
	_capture = {}
	_settings.hide()
	get_tree().paused = _settings_was_paused
	if is_instance_valid(_settings_return_focus) and _settings_return_focus.is_visible_in_tree():
		_settings_return_focus.grab_focus()

## The first press asks; the second, while still paused, quits.
func _quit_pressed() -> void:
	if _pause_quit.text == QUIT_LABEL:
		_pause_quit.text = QUIT_CONFIRM
		return
	Flow.stop()

## Losing the controller in use pauses the game instead of letting timers,
## choices and prompts run on with nobody able to answer them.
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected or not Flow.running or not CADInputDevice.using_pad:
		return
	if not get_tree().paused:
		set_paused(true)
	notice("Controller disconnected.")

func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause.visible = paused
	_pause_quit.text = QUIT_LABEL
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
	if _settings.visible and not _capture.is_empty():
		# Everything goes to the rebinding prompt, including Pause and Back.
		_capture_input(event)
		get_viewport().set_input_as_handled()
		return
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
