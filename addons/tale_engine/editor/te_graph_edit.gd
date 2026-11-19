@tool
class_name TEGraphEdit
extends RefCounted
## Changes the graph dock makes to an episode, each one undoable. Kept apart
## from the dock so tests can run them without the editor.

var episode: TEEpisode
var undo_redo := UndoRedo.new()
## Emitted after any change, done or undone, so the view can redraw and save.
signal changed

func _init(target: TEEpisode = null) -> void:
	episode = target

func _notification(what: int) -> void:
	# UndoRedo is a plain Object; free it with its owner.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(undo_redo):
		undo_redo.free()

## Point exit `port` of `from` at `to` (a step id or END).
func connect_exit(from: StringName, port: int, to: StringName) -> bool:
	var exit := _exit(from, port)
	if exit == null or (to != TEGraphLayout.END and episode.find(to) == null) or exit.next == to:
		return false
	undo_redo.create_action("Connect %s -> %s" % [from, to])
	undo_redo.add_do_property(exit, &"next", to)
	undo_redo.add_undo_property(exit, &"next", exit.next)
	_finish()
	return true

## Leave exit `port` of `from` pointing nowhere.
func disconnect_exit(from: StringName, port: int) -> bool:
	var exit := _exit(from, port)
	if exit == null or exit.next == &"":
		return false
	undo_redo.create_action("Disconnect %s" % from)
	undo_redo.add_do_property(exit, &"next", &"")
	undo_redo.add_undo_property(exit, &"next", exit.next)
	_finish()
	return true

## Add an exit to a step, on `on`, pointing nowhere yet.
func add_exit(from: StringName, on: StringName = &"*") -> bool:
	var step := episode.find(from)
	if step == null:
		return false
	var exit := TEExit.new()
	exit.on = on
	var before := step.exits.duplicate()
	var after := step.exits.duplicate()
	after.append(exit)
	undo_redo.create_action("Add exit to %s" % from)
	undo_redo.add_do_property(step, &"exits", after)
	undo_redo.add_undo_property(step, &"exits", before)
	_finish()
	return true

## Remove steps. Exits that led to them are left dangling for the validator
## to point out, rather than silently rerouted.
func delete_steps(ids: Array[StringName]) -> bool:
	var before := episode.steps.duplicate()
	var after: Array[TEStep] = []
	for step in episode.steps:
		if step == null or step.id not in ids:
			after.append(step)
	if after.size() == before.size():
		return false
	undo_redo.create_action("Delete %s" % ", ".join(ids))
	undo_redo.add_do_property(episode, &"steps", after)
	undo_redo.add_undo_property(episode, &"steps", before)
	_finish()
	return true

## Add a step of `kind` with one exit to END. Returns it.
func add_step(kind: int) -> TEStep:
	var step := TEStep.new()
	var index := episode.steps.size() + 1
	while episode.find(StringName("step_%d" % index)) != null:
		index += 1
	step.id = StringName("step_%d" % index)
	step.kind = kind
	step.title = String(step.id)
	var exit := TEExit.new()
	exit.next = TEGraphLayout.END
	step.exits = [exit] as Array[TEExit]
	var before := episode.steps.duplicate()
	var after := episode.steps.duplicate()
	after.append(step)
	undo_redo.create_action("Add %s" % step.id)
	undo_redo.add_do_property(episode, &"steps", after)
	undo_redo.add_undo_property(episode, &"steps", before)
	_finish()
	return step

## Remember where a node was dragged to. Not undoable on its own.
func move_step(id: StringName, at: Vector2) -> void:
	episode.editor_positions[id] = at
	changed.emit()

func undo() -> bool:
	var done := undo_redo.undo()
	if done:
		changed.emit()
	return done

func redo() -> bool:
	var done := undo_redo.redo()
	if done:
		changed.emit()
	return done

func _finish() -> void:
	undo_redo.commit_action()
	changed.emit()

func _exit(from: StringName, port: int) -> TEExit:
	var step := episode.find(from) if episode != null else null
	if step == null or port < 0 or port >= step.exits.size():
		return null
	return step.exits[port]
