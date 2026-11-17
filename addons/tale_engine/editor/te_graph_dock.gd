@tool
class_name TEGraphDock
extends VBoxContainer
## Bottom-panel view of a TEEpisode: the step graph, a validation list and a
## button to add steps. Clicking a step selects its resource in the inspector.

signal inspect_requested(resource: Resource)
signal save_requested(resource: Resource)

var episode: TEEpisode
## Returns a PackedStringArray of problems for an episode. The editor plugin swaps
## in a subprocess check, since game autoloads are not loaded in the editor.
var validator := func(target: TEEpisode) -> PackedStringArray: return TEValidator.check(target)

var _title := Label.new()
var _graph := GraphEdit.new()
var _problems := ItemList.new()
var _kind_picker := OptionButton.new()

func _init() -> void:
	name = "Tale Engine"
	custom_minimum_size = Vector2(0, 280)
	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_title)
	_title.text = "Select an episode resource to see its graph."
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for kind_name: String in ["Explore", "Dialogue", "Encounter", "Card", "Cutscene"]:
		_kind_picker.add_item(kind_name)
	bar.add_child(_kind_picker)
	var add := Button.new()
	add.text = "Add step"
	add.pressed.connect(_add_step)
	bar.add_child(add)
	var validate := Button.new()
	validate.text = "Validate"
	validate.pressed.connect(validate_episode)
	bar.add_child(validate)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph.right_disconnects = false
	split.add_child(_graph)
	_problems.custom_minimum_size = Vector2(320, 0)
	split.add_child(_problems)

func show_episode(new_episode: TEEpisode) -> void:
	episode = new_episode
	rebuild()

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
			nodes[step.id] = _make_node(step, TEGraphLayout.position_of(cells[step.id]))
	var end_node := _make_end_node(cells)
	for edge in TEGraphLayout.edges(episode):
		var source: GraphNode = nodes.get(edge["from"])
		var target: GraphNode = end_node if edge["to"] == TEGraphLayout.END else nodes.get(edge["to"])
		if source != null and target != null:
			_graph.connect_node(source.name, edge["port"], target.name, 0)

func validate_episode() -> PackedStringArray:
	_problems.clear()
	if episode == null:
		return PackedStringArray()
	var errors: PackedStringArray = validator.call(episode)
	if errors.is_empty():
		_problems.add_item("No problems found.")
	for problem in errors:
		_problems.add_item(problem)
	return errors

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
		row.text = "-> %s" % (String(exit.on) if exit != null else "?")
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		node.add_child(row)
		node.set_slot(i + 1, false, 0, Color.WHITE, true, 0, Color(0.5, 0.8, 1.0))
	node.node_selected.connect(inspect_requested.emit.bind(step))
	_graph.add_child(node)
	return node

func _make_end_node(cells: Dictionary) -> GraphNode:
	var column := 0
	for cell: Vector2i in cells.values():
		column = maxi(column, cell.x)
	var node := GraphNode.new()
	node.name = "step_END"
	node.title = "END"
	node.position_offset = TEGraphLayout.position_of(Vector2i(column + 2, 0))
	var label := Label.new()
	label.text = "Episode ends"
	node.add_child(label)
	node.set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)
	_graph.add_child(node)
	return node

func _add_step() -> void:
	if episode == null:
		return
	var step := TEStep.new()
	var index := episode.steps.size() + 1
	while episode.find(StringName("step_%d" % index)) != null:
		index += 1
	step.id = StringName("step_%d" % index)
	step.kind = _kind_picker.selected
	step.title = String(step.id)
	var exit := TEExit.new()
	exit.next = TEGraphLayout.END
	step.exits = [exit] as Array[TEExit]
	episode.steps.append(step)
	rebuild()
	save_requested.emit(episode)
	inspect_requested.emit(step)
