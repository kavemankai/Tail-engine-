extends TestSuite
## Every string the player can read goes through translation, and the template
## tool finds all of them. Uses a made-up locale that wraps each string in « ».

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")
const LOCALE := "zz"
## Text that is deliberately the same in every language.
const UNTRANSLATED := ["Xbox", "PlayStation", "Nintendo", "1.5×", "2×", "3×"]

var _translation: Translation

func run() -> void:
	Flow.save_slot = -1
	Settings.reset()
	template()
	install()
	await menus()
	await in_game()
	await switching_back()
	Flow.stop()
	await frames(3)
	TranslationServer.remove_translation(_translation)
	Settings.reset()
	Screen.clear_history()
	Flow.save_slot = 0

func template() -> void:
	var engine := TEStrings.engine()
	expect(engine.size() > 80 and "Resume" in engine and "Save slot: %d" in engine and "Hold " in engine
		and "Move left" in engine and "D-pad Up" in engine, "the engine template covers menus, prompts and control names")
	expect("PAUSED\n[%s] resume" in engine, "escaped newlines are read as the real string")
	var content := TEStrings.content(EPISODE)
	expect(EPISODE.title in content and "You insulted the stranger." in content, "episode titles and recap sentences are collected")
	var labels := 0
	for step in EPISODE.steps:
		if step.heading != "" and step.heading in content:
			labels += 1
	expect(labels > 0 and "Look" in content, "card headings and hotspot verbs are collected")
	var pot := TEStrings.to_pot({"Interface": engine, "Episode": content})
	expect(pot.count("\nmsgid ") == engine.size() + content.size() - _overlap(engine, content)
		and "msgid \"PAUSED\\n[%s] resume\"" in pot, "the template lists each string once, escaped")

func _overlap(a: PackedStringArray, b: PackedStringArray) -> int:
	var shared := 0
	for text in b:
		if text in a:
			shared += 1
	return shared

func install() -> void:
	_translation = Translation.new()
	_translation.locale = LOCALE
	for source in TEStrings.engine() + TEStrings.content(EPISODE):
		_translation.add_message(source, "«%s»" % source)
	TranslationServer.add_translation(_translation)
	Settings.language = LOCALE
	Settings.apply()
	expect(TranslationServer.get_locale() == LOCALE, "choosing a language in settings switches the locale")

## Texts under `root` that a player can read and that were not translated.
func untranslated(root: Node, skip: Array = []) -> Array[String]:
	var missing: Array[String] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node.name in skip or (node is CanvasItem and not node.is_visible_in_tree()):
			continue
		var texts: Array[String] = []
		if node is OptionButton:
			for i in node.item_count:
				texts.append(node.get_item_text(i))
		elif node is Label or node is Button:
			texts.append(node.text)
		for text in texts:
			if not _has_words(text) or text in UNTRANSLATED or "«" in text:
				continue
			missing.append(text)
	return missing

func _has_words(text: String) -> bool:
	var letters := RegEx.new()
	letters.compile("[A-Za-z]{2,}")
	return letters.search(text) != null

func menus() -> void:
	Screen.open_settings()
	# Key and button names come from the system and the controller, and each
	# language is listed under its own name.
	var missing := untranslated(Screen._settings, ["keys", "pad", "language"])
	expect(missing.is_empty(), "every settings label is translated: " + ", ".join(missing))
	var languages := Screen._settings.find_child("language", true, false) as OptionButton
	expect(languages != null and languages.item_count >= 2, "the language option appears once translations are loaded")
	Screen.close_settings()
	Screen.log_line("Ada", "Hello.")
	Flow.new_game(EPISODE)
	await Flow.step_started
	Screen.set_paused(true)
	missing = untranslated(Screen._pause)
	expect(missing.is_empty() and "«" in Screen._pause_hint.text, "the pause menu is translated: " + ", ".join(missing))
	Screen._quit_pressed()
	expect("«" in Screen._pause_quit.text, "the quit confirmation is translated")
	Screen.open_history()
	expect(untranslated(Screen._history).is_empty(), "the history screen is translated")
	Screen.close_history()
	Screen.set_paused(false)
	Flow.stop()
	await frames(3)
	var menu := TETitleMenu.new()
	menu.episode = EPISODE
	add_child(menu)
	await frames(2)
	missing = untranslated(menu)
	expect(missing.is_empty(), "the title menu is translated: " + ", ".join(missing))
	menu._confirm("Start over? The save in slot %d will be replaced." % 1, func() -> void: pass)
	expect(untranslated(menu, []).size() <= 1, "the confirmation buttons are translated")
	menu.free()

func in_game() -> void:
	Screen.notice("Controller disconnected.")
	expect(Screen._notice.text == "«Controller disconnected.»", "notices are translated when shown")
	Screen.loading(0.5)
	expect(Screen._loading.text.begins_with("«"), "the loading indicator is translated")
	Screen.loading(-1.0)
	Flow.new_game(EPISODE)
	Flow.jump(&"bar_hub")
	var hub: TEHub = await Flow.hub_entered
	Flow.actors[&"player"].global_position = hub.get_node("Stool").global_position
	await frames(3)
	expect("«" in Screen._hint.text and Screen._hint.text.begins_with("["), "hotspot verbs are translated, button names are not")
	Flow.jump(&"bar_fight")
	var director: CADDirector = await Flow.director_started
	await director.gate_opened
	expect("«" in Screen.prompt_label.text, "action prompt labels are translated")
	Flow.jump(&"recap")
	await frames(10)
	Story.choose(&"stranger", &"insult")
	expect("«" in Screen._card_hint.text, "card prompts are translated")
	expect(Story.recap()[0] == "«You insulted the stranger.»", "recap sentences are translated")
	expect(TEBindings.label(&"te_interact") == "«Interact»", "control names are translated")
	Flow.stop()
	await frames(3)

func switching_back() -> void:
	Screen.open_settings()
	Settings.language = ""
	Settings.apply()
	await frames(2)
	expect(TranslationServer.get_locale() != LOCALE and Screen._settings.visible, "returning to the system language keeps the menu open")
	var leftovers: Array[String] = []
	for node in Screen._settings.find_children("*", "Label", true, false):
		if "«" in node.text:
			leftovers.append(node.text)
	expect(leftovers.is_empty(), "and redraws it in that language at once")
	Screen.close_settings()
