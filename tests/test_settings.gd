extends TestSuite

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	var existed := FileAccess.file_exists(Settings.PATH)
	var original := FileAccess.get_file_as_bytes(Settings.PATH) if existed else PackedByteArray()
	var old_values: Dictionary = {}
	for key: String in Settings.LIMITS:
		old_values[key] = Settings.get(key)
	Flow.save_slot = -1
	await settings_menu()
	await device_prompts()
	var config := ConfigFile.new()
	config.set_value("settings", "master_volume", 9.0)
	config.set_value("settings", "subtitle_size", "huge")
	config.set_value("settings", "qte_window_scale", -1)
	config.set_value("settings", "choice_time_scale", NAN)
	config.set_value("settings", "process_mode", Node.PROCESS_MODE_DISABLED)
	config.save(Settings.PATH)
	Settings.reload()
	expect(Settings.master_volume == 1.0 and Settings.qte_window_scale == 1.0,
		"out-of-range persisted settings are clamped")
	expect(Settings.subtitle_size == 36 and is_finite(Settings.choice_time_scale)
		and Settings.process_mode != Node.PROCESS_MODE_DISABLED, "invalid values and unknown settings are ignored")
	if existed:
		var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	for key: String in old_values:
		Settings.set(key, old_values[key])
	Settings.apply()
	Flow.save_slot = 0
	keyboard()

func settings_menu() -> void:
	Screen.open_settings()
	expect(Screen._settings.visible and get_tree().paused
		and get_viewport().gui_get_focus_owner() == Screen._settings_focus, "settings opens with focus and pauses gameplay")
	var subtitles := Screen._settings.find_child("subtitle_size", true, false) as OptionButton
	subtitles.select(3)
	subtitles.item_selected.emit(3)
	var choices := Screen._settings.find_child("choice_time_scale", true, false) as OptionButton
	choices.select(3)
	choices.item_selected.emit(3)
	var qte := Screen._settings.find_child("qte_window_scale", true, false) as OptionButton
	qte.select(2)
	qte.item_selected.emit(2)
	var reading := Screen._settings.find_child("text_hold_scale", true, false) as OptionButton
	reading.select(2)
	reading.item_selected.emit(2)
	var volume := Screen._settings.find_child("MasterVolume", true, false) as HSlider
	volume.value = 0.4
	Settings.subtitle_size = 24
	Settings.choice_time_scale = 1.0
	Settings.qte_window_scale = 1.0
	Settings.reload()
	expect(Settings.subtitle_size == 36 and Settings.choice_time_scale == 0.0 and Settings.qte_window_scale == 2.0,
		"menu options persist and reload, including untimed choices")
	expect(Settings.text_hold_scale == 1.5 and is_equal_approx(Settings.master_volume, 0.4), "reading time and volume persist through menu controls")
	Screen.close_settings()
	expect(not get_tree().paused and not Screen._settings.visible, "closing settings from menu restores unpaused state")
	Flow.new_game(EPISODE)
	Flow.jump(&"stranger_talk")
	var balloon: TEBalloon = await Flow.balloon_opened
	await balloon.choices_shown
	expect(balloon._text.get_theme_font_size(&"normal_font_size") == 36 and not balloon._timer.visible,
		"new dialogue uses subtitle size and untimed-choice setting")
	Flow.stop()
	await frames(3)

func device_prompts() -> void:
	keyboard()
	pad(JOY_BUTTON_LEFT_STICK)
	expect(CADInputDevice.using_pad, "real gamepad event updates shared device state")
	Flow.new_game(EPISODE)
	Flow.jump(&"stranger_talk")
	var balloon: TEBalloon = await Flow.balloon_opened
	await balloon.choices_shown
	expect(balloon._choices.get_child(0).text.begins_with("[Y]"), "dialogue inherits the last input device")
	keyboard()
	expect(balloon._choices.get_child(0).text.begins_with("[1]"), "visible dialogue prompts update on device switch")
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.1
	Input.parse_input_event(drift)
	Input.flush_buffered_events()
	expect(not CADInputDevice.using_pad, "stick drift does not switch prompts")
	Flow.stop()
	await frames(3)
	Flow.new_game(EPISODE)
	Flow.jump(&"bar_hub")
	var hub: TEHub = await Flow.hub_entered
	Flow.actors[&"player"].global_position = hub.get_node("Stool").global_position
	pad(JOY_BUTTON_LEFT_STICK)
	await frames(2)
	expect(Screen._hint.text.begins_with("[A]"), "exploration uses controller interaction glyph")
	Screen.set_paused(true)
	expect("Start" in Screen._pause_hint.text, "pause screen uses controller glyph")
	Screen.set_paused(false)
	Flow.stop()
	await frames(3)
	Flow.new_game(EPISODE)
	Flow.jump(&"bar_fight")
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	expect("[A]" in Screen.prompt_label.text, "action prompt inherits the shared device")
	keyboard()
	await frames(2)
	expect("[Space]" in Screen.prompt_label.text, "open action prompt updates on device switch")
	Flow.stop()
	await frames(3)

func keyboard() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F8
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
