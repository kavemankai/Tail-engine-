@tool
class_name TEGraphDock
extends VBoxContainer
## Bottom-panel view and editor of a TEEpisode's step graph.
##   drag from an exit to a step     connect that exit
##   drag an exit away                disconnect it
##   select steps, Delete             delete them
##   drag a step                      move it; the position is kept
##   Undo / Redo buttons, Ctrl+Z / Ctrl+Shift+Z while the graph has focus
## Exit rows show their condition. Clicking a step inspects its resource.
## Validation runs on a worker thread, so a slow check never freezes the editor.

signal inspect_requested(resource: Resource)
signal save_requested(resource: Resource)
## Emitted on the main thread when a background validation finishes.
signal validated(problems: PackedStringArray)

const KINDS: PackedStringArray = ["Explore", "Dialogue", "Encounter", "Card", "Cutscene", "Timeline"]

var episode: TEEpisode
## Returns a PackedStringArray of problems for an episode. The editor plugin swaps
## in a subprocess check, since game autoloads are not loaded in the editor.
var validator := func(target: TEEpisode) -> PackedStringArray: return TEValidator.check(target)
var edits: TEGraphEdit

var _title := Label.new()
var _graph := GraphEdit.new()
var _problems := ItemList.new()
var _kind_picker := OptionButton.new()
var _validate_button := Button.new()
var _thread: Thread

func _init() -> void:
	name = "Tale Engine"
	custom_minimum_size = Vector2(0, 280)
	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_title)
	_title.text = "Select an episode resource to see its graph."
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind_name in KINDS:
		_kind_picker.add_item(kind_name)
	bar.add_child(_kind_picker)
	for item: Array in [["Add step", _add_step], ["Undo", undo], ["Redo", redo]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		bar.add_child(button)
	_validate_button.text = "Validate"
	_validate_button.pressed.connect(validate_async)
	bar.add_child(_validate_button)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = true
	_graph.connection_request.connect(_on_connect)
	_graph.disconnection_request.connect(_on_disconnect)
	_graph.delete_nodes_request.connect(_on_delete)
	_graph.end_node_move.connect(_on_moved)
	_graph.gui_input.connect(_on_graph_input)
	split.add_child(_graph)
	_problems.custom_minimum_size = Vector2(320, 0)
	split.add_child(_problems)

func show_episode(new_episode: TEEpisode) -> void:
	episode = new_episode
	edits = TEGraphEdit.new(episode)
	edits.changed.connect(_on_changed)
	rebuild()

func undo() -> void:
	if edits != null:
		edits.undo()

func redo() -> void:
	if edits != null:
		edits.redo()

func rebuild() -> void:
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphNode:
			_graph.remove_child(child)
			child.queue_free()
	if episode == null:
		return
	_title.text = "%s  (%d steps)" % [episode.title if episode.title != "" else String(episode.id), episode.steps.size()]
	var cells := TEGraphLayout.cells(episode)
	var nodes: Dictionary = {}
	for step in episode.steps:
		if step != null:
			var at: Variant = episode.editor_positions.get(step.id)
			nodes[step.id] = _make_node(step, at if at is Vector2 else TEGraphLayout.position_of(cells[step.id]))
	var end_node := _make_end_node(cells)
	for edge in TEGraphLayout.edges(episode):
		var source: GraphNode = nodes.get(edge["from"])
		var target: GraphNode = end_node if edge["to"] == TEGraphLayout.END else nodes.get(edge["to"])
		if source != null and target != null:
			_graph.connect_node(source.name, edge["port"], target.name, 0)

## Validate now, on this thread. Tests and the command line use this.
func validate_episode() -> PackedStringArray:
	if episode == null:
		_show_problems(PackedStringArray())
		return PackedStringArray()
	var errors: PackedStringArray = validator.call(episode)
	_show_problems(errors)
	return errors

## Validate on a worker thread; `validated` fires when done. False if a check
## is already running.
func validate_async() -> bool:
	if episode == null or is_validating():
		return false
	_problems.clear()
	_problems.add_item("Validating…")
	_validate_button.disabled = true
	_thread = Thread.new()
	_thread.start(_validate_worker.bind(episode))
	return true

func is_validating() -> bool:
	return _thread != null

func _validate_worker(target: TEEpisode) -> void:
	var errors: PackedStringArray = validator.call(target)
	_validation_done.call_deferred(errors)

func _validation_done(errors: PackedStringArray) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	_validate_button.disabled = false
	_show_problems(errors)
	validated.emit(errors)

func _show_problems(errors: PackedStringArray) -> void:
	_problems.clear()
	if errors.is_empty():
		_problems.add_item("No problems found.")
	for problem in errors:
		_problems.add_item(problem)

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

func _make_node(step: TEStep, at: Vector2) -> GraphNode:
	var node := GraphNode.new()
	node.name = "step_%s" % step.id
	node.title = "%s  [%s]" % [step.id, TEGraphLayout.kind_name(step.kind)]
	node.position_offset = at
	node.draggable = true
	var summary := Label.new()
	summary.text = step.title if step.title != "" else " "
	node.add_child(summary)
	node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	for i in step.exits.size():
		var exit := step.exits[i]
		var row := Label.new()
		row.text = exit_label(exit)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		node.add_child(row)
		var conditional := exit != null and exit.when.strip_edges() != ""
		node.set_slot(i + 1, false, 0, Color.WHITE, true, 0, Color(1.0, 0.8, 0.4) if conditional else Color(0.5, 0.8, 1.0))
	var add_exit := Button.new()
	add_exit.text = "+ exit"
	add_exit.flat = true
	add_exit.pressed.connect(func() -> void: edits.add_exit(step.id))
	node.add_child(add_exit)
	node.node_selected.connect(inspect_requested.emit.bind(step))
	_graph.add_child(node)
	return node

## "on -> next" plus the condition, as shown on an exit row.
static func exit_label(exit: TEExit) -> String:
	if exit == null:
		return "?"
	var text := String(exit.on)
	if exit.when.strip_edges() != "":
		text += "  if " + exit.when.strip_edges()
	if exit.next == &"":
		text += "  (unconnected)"
	return text

func _make_end_node(cells: Dictionary) -> GraphNode:
	var column := 0
	for cell: Vector2i in cells.values():
		column = maxi(column, cell.x)
	var node := GraphNode.new()
	node.name = "step_END"
	node.title = "END"
	var at: Variant = episode.editor_positions.get(TEGraphLayout.END)
	node.position_offset = at if at is Vector2 else TEGraphLayout.position_of(Vector2i(column + 2, 0))
	var label := Label.new()
	label.text = "Episode ends"
	node.add_child(label)
	node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	_graph.add_child(node)
	return node

static func _step_id(node_name: StringName) -> StringName:
	return StringName(String(node_name).trim_prefix("step_"))

func _on_connect(from_node: StringName, from_port: int, to_node: StringName, _to_port: int) -> void:
	if edits != null:
		edits.connect_exit(_step_id(from_node), from_port, _step_id(to_node))

func _on_disconnect(from_node: StringName, from_port: int, _to_node: StringName, _to_port: int) -> void:
	if edits != null:
		edits.disconnect_exit(_step_id(from_node), from_port)

func _on_delete(names: Array[StringName]) -> void:
	var ids: Array[StringName] = []
	for node_name in names:
		var id := _step_id(node_name)
		if id != TEGraphLayout.END:
			ids.append(id)
	if edits != null and not ids.is_empty():
		edits.delete_steps(ids)

func _on_moved() -> void:
	if edits == null:
		return
	for child in _graph.get_children():
		if child is GraphNode and child.selected:
			edits.move_step(_step_id(child.name), child.position_offset)

func _on_graph_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_command_or_control_pressed() and event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
		_graph.accept_event()

func _on_changed() -> void:
	# A node's own button may have caused this; redraw after its signal returns.
	rebuild.call_deferred()
	save_requested.emit(episode)

func _add_step() -> void:
	if episode == null or edits == null:
		return
	var step := edits.add_step(_kind_picker.selected)
	inspect_requested.emit(step)
