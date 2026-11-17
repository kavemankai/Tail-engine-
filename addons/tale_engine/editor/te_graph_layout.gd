class_name TEGraphLayout
extends RefCounted
## Pure layout for the episode graph view: which column and row each step sits
## in, and which edges connect them. No editor classes, so tests can run it.

const END := &"END"
const COLUMN_WIDTH := 300.0
const ROW_HEIGHT := 190.0

## Step id -> Vector2i(column, row). Columns follow distance from the entry;
## unreachable steps go in a final column. END is not included.
static func cells(episode: TEEpisode) -> Dictionary:
	var depth: Dictionary = {}
	var queue: Array[StringName] = []
	if episode.find(episode.entry) != null:
		depth[episode.entry] = 0
		queue.append(episode.entry)
	while not queue.is_empty():
		var id: StringName = queue.pop_front()
		for exit in episode.find(id).exits:
			if exit != null and exit.next != END and episode.find(exit.next) != null and not depth.has(exit.next):
				depth[exit.next] = depth[id] + 1
				queue.append(exit.next)
	var last_column := 0
	for column: int in depth.values():
		last_column = maxi(last_column, column)
	var rows: Dictionary = {}
	var result: Dictionary = {}
	for step in episode.steps:
		if step == null:
			continue
		var column: int = depth.get(step.id, last_column + 1)
		var row: int = rows.get(column, 0)
		rows[column] = row + 1
		result[step.id] = Vector2i(column, row)
	return result

static func position_of(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * COLUMN_WIDTH, cell.y * ROW_HEIGHT)

## One entry per exit: { from, port, to, label }. `port` is the exit's index in
## its step, which is also its output slot on the graph node.
static func edges(episode: TEEpisode) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for step in episode.steps:
		if step == null:
			continue
		for i in step.exits.size():
			var exit := step.exits[i]
			if exit == null:
				continue
			var label := String(exit.on)
			if exit.when.strip_edges() != "":
				label += " if " + exit.when
			result.append({"from": step.id, "port": i, "to": exit.next, "label": label})
	return result

## Short human label for a step kind.
static func kind_name(kind: int) -> String:
	match kind:
		TEStep.Kind.EXPLORE:
			return "Explore"
		TEStep.Kind.DIALOGUE:
			return "Dialogue"
		TEStep.Kind.ENCOUNTER:
			return "Encounter"
		TEStep.Kind.CARD:
			return "Card"
		TEStep.Kind.CUTSCENE:
			return "Cutscene"
	return "?"
