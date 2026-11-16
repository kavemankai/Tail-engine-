extends Control
## Title menu. Points the engine at an episode; everything else is data.

const EPISODE := preload("res://content/episode_0/episode.tres")

var _box := VBoxContainer.new()

func _ready() -> void:
	DisplayServer.window_set_title("Tale Engine - Last Call")
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
	title.text = EPISODE.title
	title.add_theme_font_size_override(&"font_size", 44)
	_box.add_child(title)
	_add("New game", Flow.new_game.bind(EPISODE))
	var save := TESave.read(Flow.save_slot)
	if not save.is_empty() and not save["checkpoints"].is_empty():
		_add("Continue", Flow.resume)
		var list: Array = save["checkpoints"]
		for i in list.size() - 1:
			_add("Rewind to: %s" % list[i]["title"], _rewind.bind(i))
	_add("Settings", Screen.open_settings)
	_add("Interaction lab", _open_lab)
	_add("Quit", get_tree().quit)
	_box.get_child(1).grab_focus.call_deferred()

func _rewind(index: int) -> void:
	if Flow.resume():
		Flow.rewind(index)

func _open_lab() -> void:
	if get_tree().change_scene_to_file("res://content/qte_lab/lab.tscn") != OK:
		Screen.notice("Could not open the interaction lab.")

func _add(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override(&"font_size", 24)
	button.pressed.connect(action)
	_box.add_child(button)
