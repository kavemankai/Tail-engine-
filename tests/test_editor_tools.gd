extends TestSuite
## Phase 8: graph editing with undo, kept positions, edge conditions,
## background validation, the new validator rules, and pinned enum values.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	enum_pins()
	graph_edits()
	await dock()
	await background_validation()
	validator_rules()

## Resources store enums as numbers. Reordering an enum silently changes what
## every saved step, gate and spec means; these values must never move.
func enum_pins() -> void:
	var pins := {
		"TEStep.Kind": [TEStep.Kind, {"EXPLORE": 0, "DIALOGUE": 1, "ENCOUNTER": 2, "CARD": 3, "CUTSCENE": 4, "TIMELINE": 5}],
		"TEStep.Card": [TEStep.Card, {"TITLE": 0, "RECAP": 1, "CREDITS": 2}],
		"CADInteractionSpec.Family": [CADInteractionSpec.Family, {"GESTURE": 0, "CHOICE": 1, "TIMING": 2, "PASSIVE": 3,
			"DIRECTION": 4, "PATTERN": 5, "TARGET": 6, "PRESSURE": 7}],
		"CADInteractionSpec.Gesture": [CADInteractionSpec.Gesture, {"PRESS": 0, "HOLD": 1, "TIMED_RELEASE": 2, "CHORD": 3}],
		"CADInteractionSpec.WrongInput": [CADInteractionSpec.WrongInput, {"IGNORE": 0, "FAIL": 1}],
		"CADInteractionSpec.PatternError": [CADInteractionSpec.PatternError, {"IGNORE": 0, "RESET": 1, "FAIL": 2}],
		"CADInteractionSpec.DirectionMode": [CADInteractionSpec.DirectionMode, {"FLICK": 0, "HOLD": 1, "SELECT": 2}],
		"CADInteractionSpec.DirectionSpace": [CADInteractionSpec.DirectionSpace, {"INPUT": 0, "CAMERA": 1}],
		"CADInteractionSpec.Sector": [CADInteractionSpec.Sector, {"UP": 0, "UP_RIGHT": 1, "RIGHT": 2, "DOWN_RIGHT": 3,
			"DOWN": 4, "DOWN_LEFT": 5, "LEFT": 6, "UP_LEFT": 7}],
		"CADContextPredicate.Kind": [CADContextPredicate.Kind, {"MOMENTUM": 0, "INTENT": 1, "ACTOR_STATUS": 2, "PROP_AVAILABLE": 3}],
	}
	for enum_name: String in pins:
		var actual: Dictionary = pins[enum_name][0]
		var expected: Dictionary = pins[enum_name][1]
		var same := actual.size() == expected.size()
		for key: String in expected:
			same = same and actual.get(key, -1) == expected[key]
		expect(same, "%s keeps its stored values (append new members at the end)" % enum_name)

func copy_episode() -> TEEpisode:
	var episode: TEEpisode = EPISODE.duplicate(true)
	return episode

func graph_edits() -> void:
	var episode := copy_episode()
	var edits := TEGraphEdit.new(episode)
	var paid: TEStep = episode.find(&"paid_card")
	var original: StringName = paid.exits[0].next
	expect(edits.connect_exit(&"paid_card", 0, &"bar_hub") and paid.exits[0].next == &"bar_hub", "connecting an exit points it at the step")
	expect(not edits.connect_exit(&"paid_card", 0, &"nowhere"), "connecting to a missing step is refused")
	expect(edits.undo() and paid.exits[0].next == original, "undo restores the old target")
	expect(edits.redo() and paid.exits[0].next == &"bar_hub", "redo applies it again")
	expect(edits.disconnect_exit(&"paid_card", 0) and paid.exits[0].next == &"", "disconnecting leaves the exit unconnected")
	edits.undo()
	var count := episode.steps.size()
	expect(edits.add_exit(&"paid_card", &"later") and paid.exits.size() == 2 and paid.exits[1].on == &"later", "an exit can be added")
	edits.undo()
	expect(paid.exits.size() == 1, "and the addition undone")
	expect(edits.delete_steps([&"paid_card"]) and episode.find(&"paid_card") == null and episode.steps.size() == count - 1, "steps can be deleted")
	expect(Array(TEValidator.check(episode)).any(func(e: String) -> bool: return e.contains("missing step 'paid_card'")),
		"exits left pointing at a deleted step are reported, not silently rerouted")
	expect(edits.undo() and episode.find(&"paid_card") != null and episode.steps.size() == count, "undo brings a deleted step back")
	var added := edits.add_step(TEStep.Kind.TIMELINE)
	expect(added.kind == TEStep.Kind.TIMELINE and episode.find(added.id) == added, "a step of any kind can be added")
	edits.undo()
	expect(episode.find(added.id) == null, "adding a step can be undone")
	edits.move_step(&"bar_hub", Vector2(123, 45))
	expect(episode.editor_positions[&"bar_hub"] == Vector2(123, 45), "a moved step's position is stored on the episode")

func dock() -> void:
	var dock := TEGraphDock.new()
	add_child(dock)
	dock.show_episode(EPISODE)
	await frames(2)
	var total_exits := 0
	for step in EPISODE.steps:
		total_exits += step.exits.size()
	expect(dock._graph.get_connection_list().size() == total_exits, "the dock draws every exit")
	var episode := copy_episode()
	episode.editor_positions = {&"bar_hub": Vector2(900, 700)}
	dock.show_episode(episode)
	await frames(2)
	var hub_node := dock._graph.get_node("step_bar_hub") as GraphNode
	expect(hub_node.position_offset == Vector2(900, 700), "a stored position wins over the automatic layout")
	dock._on_connect(&"step_paid_card", 0, &"step_bar_hub", 0)
	await frames(2)
	expect(episode.find(&"paid_card").exits[0].next == &"bar_hub" and dock._graph.is_node_connected(&"step_paid_card", 0, &"step_bar_hub", 0),
		"dragging an exit onto a step connects it in the data and the view")
	dock.undo()
	await frames(2)
	expect(episode.find(&"paid_card").exits[0].next != &"bar_hub", "the Undo button reverts it")
	var conditional := TEExit.new()
	conditional.on = &"won"
	conditional.when = "bartender_friendly"
	conditional.next = &"aftermath"
	expect(TEGraphDock.exit_label(conditional) == "won  if bartender_friendly", "an exit row shows its condition")
	dock._on_delete([&"step_paid_card"] as Array[StringName])
	await frames(2)
	expect(episode.find(&"paid_card") == null and not dock._graph.has_node("step_paid_card"), "Delete removes the selected step")
	dock.free()

func background_validation() -> void:
	var dock := TEGraphDock.new()
	add_child(dock)
	dock.show_episode(EPISODE)
	dock.validator = func(_target: TEEpisode) -> PackedStringArray:
		OS.delay_msec(400)
		return PackedStringArray(["slow problem"])
	var started := Time.get_ticks_msec()
	expect(dock.validate_async(), "validation starts in the background")
	expect(Time.get_ticks_msec() - started < 100, "starting it does not block")
	expect(not dock.validate_async(), "a second check waits for the first")
	var frames_meanwhile := 0
	while dock.is_validating():
		frames_meanwhile += 1
		await get_tree().process_frame
	expect(frames_meanwhile > 3, "the editor keeps drawing while it runs")
	expect(dock._problems.get_item_text(0) == "slow problem", "its problems are listed when it finishes")
	dock.free()

func validator_rules() -> void:
	var text := """~ start
player: Pick. [#timed=soon]
- One [#opt=a]
- Two [#opt=b]
- Three [#opt=c]
- Four [#opt=d]
- Five [#opt=e]
player: Zero. [#timed=0]
- Fine
player: Wave. [#clip=dance]
stranger: Point. [#clip=player:wave]
=> END
"""
	var resource := DialogueManager.create_resource_from_text(text)
	var episode := copy_episode()
	episode.cast.find(&"player").clips = {&"wave": &"Wave"}
	var errors := PackedStringArray()
	TEValidator._check_lines(resource, episode, errors)
	var has := func(fragment: String) -> bool: return Array(errors).any(func(e: String) -> bool: return e.contains(fragment))
	expect(has.call("choice of 5 responses"), "more than four responses is reported")
	expect(has.call("#timed=soon"), "a #timed value that is not a number is reported")
	expect(has.call("#timed=0"), "a #timed value of zero is reported")
	expect(has.call("no clip 'dance'"), "a clip missing from the speaker's clip map is reported")
	expect(not has.call("[#clip=player:wave]"), "a mapped clip on another character passes")
	var clean := PackedStringArray()
	var good := DialogueManager.create_resource_from_text("~ start\nplayer: Fine. [#timed=4]\n- Yes\n- No\n=> END\n")
	TEValidator._check_lines(good, episode, clean)
	expect(clean.is_empty(), "a well-formed file passes: %s" % ", ".join(clean))
	var ghost := PackedStringArray()
	TEValidator._check_lines(DialogueManager.create_resource_from_text("~ start\nghost: Boo.\n=> END\n"), episode, ghost)
	expect(ghost.size() == 1 and ghost[0].contains("speaker 'ghost'"), "speakers come from Dialogue Manager's parse, not a pattern")
