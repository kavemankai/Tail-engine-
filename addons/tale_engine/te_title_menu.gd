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
	_rebuild()

func _process(_delta: float) -> void:
	if visible == Flow.running:
		visible = not Flow.running
		if visible:
			_rebuild()

func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = season.title if season != null and season.title != "" else episode.title
	title.add_theme_font_size_override(&"font_size", 44)
	_box.add_child(title)
	if Flow.has_next_episode():
		_add("Next episode", Flow.next_episode)
	_add("New game", _new_game)
	if slot_count > 1:
		_add("Save slot: %d" % (Flow.save_slot + 1), _cycle_slot)
	var save := TESave.read(Flow.save_slot)
	if not save.is_empty() and not save["checkpoints"].is_empty():
		_add("Continue", Flow.resume)
		var list: Array = save["checkpoints"]
		for i in list.size() - 1:
			_add("Rewind to: %s" % list[i]["title"], _rewind.bind(i))
	_add("Settings", Screen.open_settings)
	for label: String in extras:
		_add(label, _open_scene.bind(extras[label]))
	_add("Quit", get_tree().quit)
	_box.get_child(1).grab_focus.call_deferred()

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

func _add(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override(&"font_size", 24)
	button.pressed.connect(action)
	_box.add_child(button)
