extends TestSuite
## Leftovers from phases 1-4: public accessors, controller icons, voice per
## language, theme and font fallback, long-translation layout, save slots.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")
const CHOICES := "~ start\nAda: Pick one.\n- First [#opt=a]\n- Second [#opt=b]\n=> END\n"

func run() -> void:
	Flow.save_slot = -1
	accessors()
	voice_per_language()
	icons()
	await choice_icons()
	theme()
	await long_translations()
	await save_slots()
	CADInputDevice.style_override = &""
	CADInputDevice.set_device(false)
	Flow.save_slot = 0

func accessors() -> void:
	var balloon := TEBalloon.new()
	add_child(balloon)
	expect(not balloon.is_finished() and balloon.exit_name() == TEBalloon.DEFAULT_EXIT, "a balloon reports its state through public methods")
	balloon.free()
	var director := CADDirector.new()
	expect(director.run_id() == 0 and director.visit() == 0 and director.current_beat() == null and director.stage() == null,
		"the director exposes run, visit, beat and stage")
	director.free()
	var private := RegEx.new()
	private.compile("(balloon|director)\\._(finished|exit|run_id|visit|beat|stage)\\b")
	var offenders: Array[String] = []
	for path: String in ["res://addons/tale_engine/te_flow.gd", "res://addons/tale_engine/te_debug.gd", "res://addons/tale_engine/te_action_dialogue.gd"]:
		if private.search(FileAccess.get_file_as_string(path)) != null:
			offenders.append(path.get_file())
	expect(offenders.is_empty(), "Flow, the debug panel and action subtitles use no private members: " + ", ".join(offenders))

func voice_per_language() -> void:
	var folder := "res://tests/fixtures/voice"
	expect(TEVoice.find(folder, "line_1", "fr").ends_with("voice/fr/line_1.wav"), "a dubbed language's folder is tried first")
	expect(TEVoice.find(folder, "line_1", "fr_CA").ends_with("voice/fr/line_1.wav"), "a regional locale falls back to its language")
	expect(TEVoice.find(folder, "line_1", "de").ends_with("voice/line_1.wav"), "a language with no folder uses the base recording")
	expect(TEVoice.find(folder, "missing", "fr") == "", "a line with no recording has none")

func icons() -> void:
	CADInputDevice.style_override = &"xbox"
	var bottom: Texture2D = CADPrompt.icon(&"te_choice_3")
	expect(bottom != null and bottom.resource_path.ends_with("xbox/a.svg"), "the bottom face button has an Xbox icon")
	CADInputDevice.style_override = &"playstation"
	expect(CADPrompt.icon(&"te_choice_3").resource_path.ends_with("playstation/a.svg"), "and a PlayStation one when that pad is in use")
	CADInputDevice.style_override = &"nintendo"
	expect(CADPrompt.icon(&"te_choice_3").resource_path.ends_with("nintendo/a.svg"), "and a Nintendo one")
	var keys_only := &"te_test_keys_only"
	InputMap.add_action(keys_only)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F9
	InputMap.action_add_event(keys_only, key)
	expect(CADPrompt.icon(keys_only) == null, "an action with no controller button has no icon")
	InputMap.erase_action(keys_only)
	for family in ["xbox", "playstation", "nintendo"]:
		var complete := true
		for name: String in CADPrompt.ICON_KEYS.values() + CADPrompt.ICON_AXES.values():
			complete = complete and ResourceLoader.exists("%s/%s/%s.svg" % [CADPrompt.icon_root, family, name])
		expect(complete, "the %s icon set covers every button" % family)

func choice_icons() -> void:
	CADInputDevice.style_override = &"xbox"
	CADInputDevice.set_device(true)
	var resource := DialogueManager.create_resource_from_text(CHOICES)
	var seen := {"buttons": []}
	var on_open := func(balloon: TEBalloon) -> void:
		balloon.choices_shown.connect(func(_line: DialogueLine, _responses: Array) -> void:
			await get_tree().process_frame
			for button: Button in balloon._choices.get_children():
				seen.buttons.append([button.icon, button.text])
			balloon.pick(0))
	Flow.balloon_opened.connect(on_open)
	Settings.text_hold_scale = 0.75
	Engine.time_scale = 6.0
	await Flow.converse(resource, "start")
	Engine.time_scale = 1.0
	Flow.balloon_opened.disconnect(on_open)
	expect(seen.buttons.size() == 2 and seen.buttons.all(func(entry: Array) -> bool: return entry[0] is Texture2D),
		"on a controller, response buttons show button icons")
	expect(seen.buttons.size() == 2 and not seen.buttons[0][1].contains("["), "and drop the bracketed name")
	CADInputDevice.set_device(false)
	Settings.text_hold_scale = 1.0

func theme() -> void:
	var path := String(ProjectSettings.get_setting("gui/theme/custom", ""))
	expect(path.ends_with("tale_theme.tres") and ResourceLoader.exists(path), "the project uses the engine's theme, so a game restyles by swapping it")
	var font := (load(path) as Theme).default_font
	expect(font != null and font.fallbacks.size() >= 2, "the theme's font falls back to system fonts for other scripts")
	var names := PackedStringArray()
	for fallback: Font in font.fallbacks:
		if fallback is SystemFont:
			names.append_array(fallback.font_names)
	expect("Noto Sans CJK SC" in names and "Noto Sans Arabic" in names and "Microsoft YaHei UI" in names,
		"fallbacks name CJK and right-to-left fonts on Windows and Linux/Deck")

## Long translations: every label and button on the settings and pause
## screens stays inside the 1280-wide window when text grows by half.
func long_translations() -> void:
	var ratio: float = ProjectSettings.get_setting("internationalization/pseudolocalization/expansion_ratio", 0.0)
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.5)
	TranslationServer.pseudolocalization_enabled = true
	TranslationServer.reload_pseudolocalization()
	Screen.open_settings()
	await frames(3)
	var outside := overflowing(Screen._settings)
	expect(outside.is_empty(), "settings fit with 50%% longer text: %s" % ", ".join(outside))
	Screen.close_settings()
	Flow.new_game(EPISODE)
	await Flow.step_started
	Screen.set_paused(true)
	await frames(3)
	outside = overflowing(Screen._pause)
	expect(outside.is_empty(), "the pause menu fits with 50%% longer text: %s" % ", ".join(outside))
	Screen.set_paused(false)
	Flow.stop()
	await frames(3)
	TranslationServer.pseudolocalization_enabled = false
	ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", ratio)
	TranslationServer.reload_pseudolocalization()

func overflowing(root: Node) -> Array[String]:
	var width := get_viewport().get_visible_rect().size.x
	var found: Array[String] = []
	for node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if not control.is_visible_in_tree() or (control is not Label and control is not Button):
			continue
		var rect := control.get_global_rect()
		var text: String = control.text
		if text != "" and (rect.position.x < -1.0 or rect.end.x > width + 1.0):
			found.append("%s (%d..%d)" % [text.left(24), rect.position.x, rect.end.x])
	return found

func save_slots() -> void:
	TESave.erase(1)
	TESave.erase(2)
	var start := [{"step": EPISODE.entry, "title": "The bar", "story": Story.to_dict()}]
	expect(TESave.write(1, EPISODE.resource_path, start, {}, {"playtime": 600.0}), "a save is written to slot 2")
	var menu := TETitleMenu.new()
	menu.episode = EPISODE
	add_child(menu)
	await frames(2)
	menu._slots()
	var filled := menu.find_child("slot_1", true, false) as Button
	var empty := menu.find_child("slot_2", true, false) as Button
	expect(filled != null and filled.text.contains("The bar") and filled.text.contains("10"), "the slot screen shows each slot's checkpoint and time played")
	expect(empty != null and empty.text.contains("Empty"), "an empty slot says so")
	filled.pressed.emit()
	expect(Flow.save_slot == 1, "choosing a slot makes it the current one")
	await frames(2)
	menu.queue_free()
	await frames(2)
	TESave.erase(1)
