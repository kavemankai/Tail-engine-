@tool
extends EditorPlugin
## Adds the Tale Engine bottom panel. Selecting a TEEpisode resource in the
## FileSystem or inspector shows its step graph.

var _dock: TEGraphDock

func _enter_tree() -> void:
	_dock = TEGraphDock.new()
	_dock.validator = _validate_in_game
	_dock.inspect_requested.connect(func(resource: Resource) -> void: EditorInterface.edit_resource(resource))
	_dock.save_requested.connect(func(resource: Resource) -> void:
		if resource.resource_path != "":
			ResourceSaver.save(resource))
	add_control_to_bottom_panel(_dock, "Tale Engine")

## Run the real validator in a headless game process and collect its problems.
func _validate_in_game(episode: TEEpisode) -> PackedStringArray:
	var problems := PackedStringArray()
	if episode.resource_path == "":
		problems.append("Save the episode before validating.")
		return problems
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://addons/tale_engine/editor/validate_cli.tscn", "--", episode.resource_path], output, true)
	for line: String in "".join(output).split("\n"):
		if line.begins_with("PROBLEM: "):
			problems.append(line.trim_prefix("PROBLEM: ").strip_edges())
	if problems.is_empty() and code > 1:
		problems.append("The validator process failed (exit code %d)." % code)
	return problems

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null

func _handles(object: Object) -> bool:
	return object is TEEpisode

func _edit(object: Object) -> void:
	if object is TEEpisode and _dock != null:
		_dock.show_episode(object)

func _make_visible(visible: bool) -> void:
	if visible and _dock != null:
		make_bottom_panel_item_visible(_dock)
