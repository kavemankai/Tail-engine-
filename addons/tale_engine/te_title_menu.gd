class_name TETitleMenu
extends Control
## Reusable title menu: New game, Continue, Rewind, Settings, Quit.
## Set `episode` (and optionally `window_title` and `extras`) on the node, or
## subclass it. Everything else about the game is data.

@export var episode: TEEpisode
@export var window_title := "Tale Engine"
## Extra buttons: label -> scene path opened with change_scene_to_file.
@export var extras: Dictionary = {}

var _box := VBoxContainer.new()

func _ready() -> void:
	if episode == null:
		push_error("TETitleMenu needs an episode.")
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
	title.text = episode.title
	title.add_theme_font_size_override(&"font_size", 44)
	_box.add_child(title)
	_add("New game", Flow.new_game.bind(episode))
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
