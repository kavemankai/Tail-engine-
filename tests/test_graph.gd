extends TestSuite
## Episode graph layout used by the editor dock, and the dock itself.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	var cells := TEGraphLayout.cells(EPISODE)
	expect(cells.size() == EPISODE.steps.size(), "every step gets a cell")
	expect(cells[EPISODE.entry] == Vector2i(0, 0), "the entry step starts the first column")
	var seen: Dictionary = {}
	var unique := true
	for cell: Vector2i in cells.values():
		unique = unique and not seen.has(cell)
		seen[cell] = true
	expect(unique, "no two steps share a cell")
	expect(cells[&"stranger_talk"].x > cells[&"bar_hub"].x, "later steps sit in later columns")

	var edges := TEGraphLayout.edges(EPISODE)
	var total_exits := 0
	for step in EPISODE.steps:
		total_exits += step.exits.size()
	expect(edges.size() == total_exits, "one edge per exit")
	expect(edges.any(func(edge: Dictionary) -> bool: return edge["from"] == &"stranger_talk" and edge["to"] == &"paid_card" and edge["label"] == "paid"),
		"edges carry exit names")

	var orphan := TEStep.new()
	orphan.id = &"orphan"
	var episode: TEEpisode = EPISODE.duplicate()
	episode.steps = EPISODE.steps.duplicate()
	episode.steps.append(orphan)
	var orphan_cell: Vector2i = TEGraphLayout.cells(episode)[&"orphan"]
	var last_reachable := 0
	for id: StringName in cells:
		last_reachable = maxi(last_reachable, cells[id].x)
	expect(orphan_cell.x == last_reachable + 1, "unreachable steps go in a final column")

	var dock := TEGraphDock.new()
	add_child(dock)
	dock.show_episode(EPISODE)
	await frames(2)
	expect(dock._graph.get_children().filter(func(node: Node) -> bool: return node is GraphNode).size() == EPISODE.steps.size() + 1,
		"the dock shows a node per step plus END")
	expect(dock._graph.get_connection_list().size() == total_exits, "the dock draws every exit")
	expect(dock.validate_episode().is_empty(), "the dock reports a clean episode")
	var copy: TEEpisode = EPISODE.duplicate()
	copy.steps = EPISODE.steps.duplicate()
	dock.show_episode(copy)
	dock._kind_picker.selected = TEStep.Kind.CUTSCENE
	dock._add_step()
	await frames(2)
	expect(copy.steps.size() == EPISODE.steps.size() + 1 and copy.steps.back().kind == TEStep.Kind.CUTSCENE, "Add step appends a step of the chosen kind")
	expect(not dock.validate_episode().is_empty(), "an unfinished new step shows up as a problem")
	dock.free()
