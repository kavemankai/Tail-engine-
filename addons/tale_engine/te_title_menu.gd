class_name TETitleMenu
extends Control
## Reusable title menu: New game, Continue, Rewind, Settings, Quit.
## Set `episode` (and optionally `window_title` and `extras`) on the node, or
## subclass it. Everything else about the game is data.

## A single episode, or leave empty and set `season` instead.
@export var episode: TEEpisode
## Multi-episode story. New game starts its first episode; a finished episode
## offers "Next episode" until the season ends.
@export var season: TESeason
## How many save slots the menu cycles through. 1 hides the selector.
@export_range(1, 9) var slot_count := 3
@export var window_title := "Tale Engine"
## Extra buttons: label -> scene path opened with change_scene_to_file.
@export var extras: Dictionary = {}

var _box := VBoxContainer.new()

func _ready() -> void:
	if season != null and not season.episodes.is_empty():
		episode = season.episodes[0]
	if episode == null:
		push_error("TETitleMenu needs an episode or a season.")
		return
	DisplayServer.window_set_title(window_title)
	_box.position = Vector2(90, 120)
	add_child(_box)
	Flow.episode_finished.connect(func(_exit: StringName) -> void: _rebuild())
	Flow.episode_failed.connect(func(_reason: String) -> void: _rebuild())
	_rebuild()

func _process(_delta: float) -> void:
	if visible == Flow.running:
		visible = not Flow.running
		if visible:
			_rebuild()

func _rebuild() -> void:
	_clear()
	_heading(season.title if season != null and season.title != "" else episode.title)
	var save := TESave.read(Flow.save_slot)
	var status := TESave.last_status
	var has_save := not save.is_empty()
	if Flow.has_next_episode():
		_add("Next episode", Flow.next_episode)
	if has_save:
		_add("Continue: %s" % _describe(save), Flow.resume)
	_add("New game", _confirm.bind("Start over? The save in slot %d will be replaced." % (Flow.save_slot + 1), _new_game) if has_save else _new_game)
	if slot_count > 1:
		_add("Save slot: %d" % (Flow.save_slot + 1), _cycle_slot)
	if has_save:
		var list: Array = save["checkpoints"]
		for i in list.size() - 1:
			_add("Rewind to: %s" % list[i]["title"],
				_confirm.bind("Rewind to \"%s\"? Later checkpoints will be lost." % list[i]["title"], _rewind.bind(i)))
	if status == TESave.Status.UNREADABLE:
		_note("The save in this slot could not be read.")
	elif status == TESave.Status.RECOVERED:
		_note("This save was updated to match the current version.")
	_add("Settings", Screen.open_settings)
	for label: String in extras:
		_add(label, _open_scene.bind(extras[label]))
	_add("Quit", get_tree().quit)
	_focus_first()

## Checkpoint name, when it was saved, and time played.
func _describe(save: Dictionary) -> String:
	var meta: Dictionary = save.get("meta", {})
	var text := String(meta.get("checkpoint_title", save["checkpoints"].back()["title"]))
	var saved_at := int(meta.get("saved_at", 0))
	if saved_at > 0:
		var date := Time.get_datetime_dict_from_unix_time(saved_at + Time.get_time_zone_from_system()["bias"] * 60)
		text += "  (%04d-%02d-%02d %02d:%02d" % [date["year"], date["month"], date["day"], date["hour"], date["minute"]]
		var minutes := int(float(meta.get("playtime", 0.0)) / 60.0)
		text += ", %d min played)" % minutes if minutes > 0 else ")"
	return text

## Replace the menu with a yes/no question. Cancel is focused first.
func _confirm(question: String, action: Callable) -> void:
	_clear()
	_heading(question, 28)
	_add("Cancel", _rebuild)
	_add("Yes", action)
	_focus_first()

func _new_game() -> void:
	if season != null:
		Flow.start_season(season)
	else:
		Flow.new_game(episode)

func _cycle_slot() -> void:
	Flow.save_slot = (Flow.save_slot + 1) % slot_count
	_rebuild()

func _rewind(index: int) -> void:
	if Flow.resume():
		Flow.rewind(index)

func _open_scene(path: String) -> void:
	if get_tree().change_scene_to_file(path) != OK:
		Screen.notice("Could not open %s." % path)

func _clear() -> void:
	# Remove now, not at end of frame, so focus never lands on a dying button.
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()

func _focus_first() -> void:
	for child in _box.get_children():
		if child is Button:
			child.grab_focus.call_deferred()
			return

func _heading(text: String, size := 44) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_font_size_override(&"font_size", size)
	_box.add_child(title)

func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 18)
	_box.add_child(label)

func _add(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override(&"font_size", 24)
	button.pressed.connect(action)
	_box.add_child(button)
	return button
