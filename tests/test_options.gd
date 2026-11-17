extends TestSuite
## Player options beyond the basics: audio buses, display, subtitles, response
## highlighting, rebinding and controller button names.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	var existed := FileAccess.file_exists(Settings.PATH)
	var original := FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
	Flow.save_slot = -1
	Settings.reset()
	audio_buses()
	persistence()
	bindings()
	binding_storage()
	controller_names()
	capture_in_menu()
	await subtitles_and_highlight()
	Settings.reset()
	if existed:
		var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
		Settings.reload()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	CADInputDevice.set_device(false)
	Flow.save_slot = 0

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func button(index: JoyButton, device := 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.device = device
	event.pressed = true
	return event

func key_of(action: StringName) -> int:
	var event := TEBindings.current(action, false) as InputEventKey
	return event.physical_keycode if event != null else KEY_NONE

func audio_buses() -> void:
	for bus: StringName in [&"Music", &"SFX", &"Voice"]:
		expect(AudioServer.get_bus_index(bus) > 0 and AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"Master",
			"%s bus exists and feeds Master" % bus)
	Settings.music_volume = 0.5
	Settings.voice_volume = 0.0
	Settings.apply()
	expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))), 0.5),
		"music volume drives its own bus")
	expect(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Voice")) < -60.0
		and is_equal_approx(AudioServer.get_bus_volume_db(0), 0.0), "silencing voices leaves the master level alone")
	expect(Audio._voice.bus == &"Voice" and Audio._music[0].bus == &"Music", "engine players use the matching buses")
	Settings.reset()

func persistence() -> void:
	Settings.subtitles = false
	Settings.choice_highlight = true
	Settings.render_scale = 0.7
	Settings.prompt_style = "playstation"
	Settings.sfx_volume = 0.25
	expect(Settings.save(), "options save")
	Settings.reset()
	expect(Settings.subtitles and not Settings.choice_highlight and Settings.render_scale == 1.0
		and Settings.prompt_style == "", "reset restores every default")
	Settings.reload()
	expect(not Settings.subtitles and Settings.choice_highlight and is_equal_approx(Settings.render_scale, 0.7)
		and Settings.prompt_style == "playstation" and is_equal_approx(Settings.sfx_volume, 0.25),
		"toggles, choices and volumes persist")
	expect(is_equal_approx(get_viewport().scaling_3d_scale, 0.7) and CADInputDevice.style() == &"playstation",
		"render scale and button naming are applied on load")
	var config := ConfigFile.new()
	config.set_value("settings", "subtitles", "no")
	config.set_value("settings", "render_scale", 0.01)
	config.set_value("settings", "language", 12)
	config.set_value("settings", "prompt_style", "x".repeat(200))
	config.set_value("input", "bindings", "nonsense")
	config.save(Settings.PATH)
	Settings.reset()
	Settings.reload()
	expect(Settings.subtitles and Settings.render_scale == 0.5 and Settings.language == "" and Settings.prompt_style == "",
		"wrong types are ignored and out-of-range values clamped")
	Settings.reset()
	Settings.save()

func bindings() -> void:
	var interact_key := key_of(&"te_interact")
	var forward_key := key_of(&"move_forward")
	var pad_before := TEBindings.current(&"te_interact", true) as InputEventJoypadButton
	expect(TEBindings.rebind(&"te_interact", key(KEY_F)) == &"" and key_of(&"te_interact") == KEY_F,
		"an action takes a new key")
	expect((TEBindings.current(&"te_interact", true) as InputEventJoypadButton).button_index == pad_before.button_index,
		"rebinding a key leaves the controller binding alone")
	expect(CADPrompt.glyph(&"te_interact", false) == "F", "prompts show the new key")
	var pressed := key(KEY_F)
	expect(pressed.is_action(&"te_interact") and not key(interact_key).is_action(&"te_interact"),
		"the new key triggers the action and the old one no longer does")

	expect(TEBindings.rebind(&"te_interact", key(forward_key)) == &"move_forward" and key_of(&"move_forward") == KEY_F,
		"taking a key used in the same mode swaps the two actions")
	var advance_key := key_of(&"te_advance")
	expect(TEBindings.rebind(&"te_advance", key(key_of(&"te_interact"))) == &"" and key_of(&"te_interact") == forward_key,
		"actions from different modes may share a key")
	expect(TEBindings.rebind(&"te_pause", key(key_of(&"cad_a"))) == &"cad_a", "pause never shares a key with anything")
	expect(key_of(&"cad_a") == KEY_ESCAPE, "the displaced action receives the old pause key")

	expect(TEBindings.rebind(&"cad_a", button(JOY_BUTTON_RIGHT_SHOULDER, 3)) == &"", "a controller button binds")
	var bound := TEBindings.current(&"cad_a", true) as InputEventJoypadButton
	expect(bound.button_index == JOY_BUTTON_RIGHT_SHOULDER and bound.device == -1, "a binding works on any controller, not only the one pressed")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 0.9
	expect(TEBindings.bindable(trigger) and TEBindings.rebind(&"cad_b", trigger) == &""
		and CADPrompt.glyph(&"cad_b", true) == "RT", "a trigger binds and is named")
	trigger.axis_value = 0.2
	expect(not TEBindings.bindable(trigger) and not TEBindings.bindable(InputEventMouseMotion.new()),
		"a resting stick or a mouse move is not taken as a binding")
	TEBindings.reset()
	expect(key_of(&"te_interact") == interact_key and key_of(&"move_forward") == forward_key
		and key_of(&"te_advance") == advance_key and key_of(&"te_pause") == KEY_ESCAPE, "reset restores the project's bindings")

func binding_storage() -> void:
	expect(TEBindings.changed_bindings().is_empty(), "default bindings store nothing")
	TEBindings.rebind(&"te_interact", key(KEY_F))
	TEBindings.rebind(&"cad_a", button(JOY_BUTTON_Y))
	var stored := TEBindings.changed_bindings()
	expect(stored.has("te_interact") and stored["te_interact"].has("keys") and not stored["te_interact"].has("pad"),
		"only changed slots are stored")
	Settings.save()
	TEBindings.reset()
	Settings.reload()
	expect(key_of(&"te_interact") == KEY_F
		and (TEBindings.current(&"cad_a", true) as InputEventJoypadButton).button_index == JOY_BUTTON_Y,
		"bindings persist with the settings")
	TEBindings.restore({"te_interact": {"keys": {"type": "key", "code": -4}, "pad": {"type": "key", "code": 70}},
		"no_such_action": {"keys": {"type": "key", "code": 70}}, 7: {}, "cad_a": "x",
		"cad_b": {"pad": {"type": "axis", "axis": 999, "sign": 1}}})
	expect(TEBindings.changed_bindings().is_empty() and not InputMap.has_action(&"no_such_action"),
		"malformed or mismatched stored bindings are ignored")
	Settings.reset()
	Settings.save()

func controller_names() -> void:
	expect(CADInputDevice.style_of("Xbox Series X Controller") == &"xbox" and CADInputDevice.style_of("") == &"xbox",
		"unknown and Xbox controllers use Xbox names")
	expect(CADInputDevice.style_of("PS5 Controller") == &"playstation" and CADInputDevice.style_of("Sony DualSense") == &"playstation",
		"PlayStation controllers are recognised")
	expect(CADInputDevice.style_of("Nintendo Switch Pro Controller") == &"nintendo", "Nintendo controllers are recognised")
	expect(CADPrompt.glyph(&"te_interact", true) == "A" and CADPrompt.glyph(&"te_pause", true) == "Start", "Xbox names by default")
	var changes := [0]
	var on_change := func(_pad: bool) -> void: changes[0] += 1
	InputDevice.changed.connect(on_change)
	Settings.prompt_style = "playstation"
	Settings.apply()
	expect(CADPrompt.glyph(&"te_interact", true) == "Cross" and CADPrompt.glyph(&"te_pause", true) == "Options"
		and changes[0] == 1, "PlayStation names replace them and open prompts are told")
	Settings.prompt_style = "nintendo"
	Settings.apply()
	expect(CADPrompt.glyph(&"te_interact", true) == "B" and CADPrompt.glyph(&"te_choice_1", true) == "X",
		"Nintendo names follow the printed letters, not the Xbox positions")
	expect(CADPrompt.glyph(&"te_interact", false) == "E", "keyboard names are unaffected")
	InputDevice.changed.disconnect(on_change)
	Settings.reset()

func capture_in_menu() -> void:
	Screen.open_settings()
	var row := Screen._settings.find_child("bind_te_interact", true, false)
	expect(row != null and row.get_node("keys").text == "E" and row.get_node("pad").text == "A",
		"the controls list shows both bindings")
	var keys: Button = row.get_node("keys")
	keys.pressed.emit()
	expect(keys.text != "E" and not Screen._capture.is_empty(), "choosing a binding waits for input")
	Screen._input(button(JOY_BUTTON_X))
	expect(not Screen._capture.is_empty() and key_of(&"te_interact") == KEY_E, "a controller press is not taken for a key binding")
	Screen._input(key(KEY_ESCAPE))
	expect(Screen._capture.is_empty() and keys.text == "E" and Screen._settings.visible, "Escape cancels without closing the menu")
	keys.pressed.emit()
	Screen._input(key(KEY_G))
	expect(Screen._capture.is_empty() and keys.text == "G" and key_of(&"te_interact") == KEY_G, "the next key becomes the binding")
	var pad_button: Button = row.get_node("pad")
	pad_button.pressed.emit()
	Screen._input(button(JOY_BUTTON_START))
	expect(Screen._settings.visible and pad_button.text == "Start"
		and (TEBindings.current(&"te_pause", true) as InputEventJoypadButton).button_index == JOY_BUTTON_A,
		"binding the pause button rebinds instead of closing the menu, and swaps")
	(Screen._settings.find_child("Reset", true, false) as Button).pressed.emit()
	row = Screen._settings.find_child("bind_te_interact", true, false)
	expect(key_of(&"te_interact") == KEY_E and row.get_node("keys").text == "E" and Screen._settings.visible,
		"reset restores bindings and rebuilds the list")
	Screen.close_settings()

func subtitles_and_highlight() -> void:
	Settings.subtitle_size = 24
	Settings.apply()
	Screen.caption("A caption")
	Settings.subtitle_size = 36
	Settings.apply()
	expect(Screen._caption.get_theme_font_size(&"font_size") == 36, "caption size follows the setting without a restart")
	Flow.new_game(EPISODE)
	Flow.jump(&"stranger_talk")
	var balloon: TEBalloon = await Flow.balloon_opened
	await balloon.choices_shown
	expect(balloon._panel.visible and balloon._choices.get_child(0).focus_mode == Control.FOCUS_NONE
		and balloon._choices.get_child(0).text.begins_with("["), "by default each response shows its own button")
	Settings.subtitles = false
	Settings.apply()
	expect(not balloon._panel.visible and not Screen._caption.visible and balloon._choices.visible,
		"turning subtitles off hides spoken text at once but keeps the responses")
	Settings.subtitles = true
	Settings.subtitle_background = false
	Settings.apply()
	expect(balloon._panel.visible and balloon._panel.color.a == 0.0, "the subtitle background can be removed")
	Flow.stop()
	await frames(3)

	Settings.reset()
	Settings.choice_highlight = true
	Settings.apply()
	Flow.new_game(EPISODE)
	Flow.jump(&"stranger_talk")
	balloon = await Flow.balloon_opened
	await balloon.choices_shown
	await frames(2)
	var first: Button = balloon._choices.get_child(0)
	expect(first.focus_mode == Control.FOCUS_ALL and get_viewport().gui_get_focus_owner() == first
		and not first.text.begins_with("["), "highlight mode focuses the first response and drops the button labels")
	tap(&"te_choice_2")
	await frames(2)
	expect(balloon.choosing() and balloon._picked == -1, "response buttons do nothing in highlight mode")
	var second: Button = balloon._choices.get_child(1)
	second.grab_focus()
	second.pressed.emit()
	await frames(2)
	expect(not balloon.choosing(), "confirming the highlighted response picks it")
	Flow.stop()
	await frames(3)
	Screen.caption("")
	Settings.reset()
