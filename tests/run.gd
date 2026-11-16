extends Node
## Headless checks. Run: godot --headless --path . res://tests/run.tscn

const BAR := preload("res://examples/bar_fight/demo.tscn")
const CHASE := preload("res://examples/alley_chase/demo.tscn")
const ACTION := &"cad_dodge"

var failures := 0
var director: CADDirector
var visit := 0
var acquired := 0
var released: Array[StringName] = []

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	DemoInput.ensure()
	await director_tests()
	Engine.time_scale = 3.0
	await bar_tests()
	await chase_tests()
	Engine.time_scale = 1.0
	print("FAILURES ", failures)
	get_tree().quit(0 if failures == 0 else 1)

# --- Director without a stage: the host sends markers -----------------------

func director_tests() -> void:
	director = CADDirector.new()
	add_child(director)
	director.beat_started.connect(func(_beat: CADBeat, number: int) -> void: visit = number)
	var acquire := func() -> bool:
		acquired += 1
		return true
	var release := func(outcome: StringName) -> void: released.append(outcome)

	expect(not CADSequence.new().validation_errors().is_empty(), "empty graph rejected")
	var broken := two_beats()
	broken.beats[1].next = &"nowhere"
	expect(not director.begin(broken), "missing destination rejected")
	broken = two_beats()
	broken.beats[1].watchdog_seconds = 0.0
	expect(not director.begin(broken), "host-driven beat without a watchdog rejected")

	# Normal run, stale markers inside one run.
	expect(director.begin(two_beats(), null, acquire, release), "run starts")
	var rival := CADDirector.new()
	add_child(rival)
	expect(not rival.begin(two_beats()), "second director cannot take the viewport")
	rival.queue_free()
	var first := visit
	expect(not director.marker(&"gate", first + 1) and not director.marker(&"other", first), "unknown marker ignored")
	expect(director.marker(&"gate", first), "marker opens the gate")
	tap(ACTION)
	await frames(2)
	expect(visit == first + 1 and not director.marker(&"done", first), "marker from the previous beat rejected")
	expect(director.marker(&"done", visit), "host completes an ungated beat")
	expect(await director.finished == &"complete", "authored outcome reached")
	expect(joined(director.trail) == "one,two" and director.results[&"one"] == &"go", "trail and results recorded")

	# Stale marker from a cancelled run.
	director.begin(two_beats(), null, acquire, release)
	var old := visit
	director.cancel()
	director.begin(two_beats(), null, acquire, release)
	expect(not director.marker(&"gate", old), "marker from a cancelled run rejected")
	director.cancel()

	# A beat nobody completes.
	director.begin(two_beats(), null, acquire, release)
	expect(await director.finished == &"watchdog", "waiting beat ends at its watchdog")

	# Suspension.
	director.begin(two_beats(), null, acquire, release)
	director.marker(&"gate", visit)
	director.suspend(true)
	await wait(0.5)
	tap(ACTION)
	expect(director.active() and director.results.is_empty(), "suspension froze the gate and blocked input")
	expect(not director.marker(&"done", visit), "suspension blocks markers")
	director.suspend(false)
	expect(await director.finished == &"missed", "gate timed out after resuming")

	# Input buffer.
	director.begin(two_beats(), null, acquire, release)
	tap(ACTION)
	await wait(0.05)
	director.marker(&"gate", visit)
	expect(director.results.get(&"one") == &"go", "press just before the gate opens counts")
	director.cancel()
	director.begin(two_beats(), null, acquire, release)
	tap(ACTION)
	await wait(0.3)
	director.marker(&"gate", visit)
	expect(director.results.is_empty(), "old press does not count")
	director.cancel()

	# Hold, and an option whose flag is missing.
	var hold := two_beats()
	hold.beats[0].gate.options[0].hold_seconds = 0.2
	hold.beats[0].gate.open_marker = &""
	director.begin(hold, null, acquire, release)
	tap(ACTION)
	expect(await director.finished == &"missed", "a tap does not satisfy a hold")
	director.begin(hold, null, acquire, release)
	send(ACTION, true)
	var result: Array = await director.gate_resolved
	send(ACTION, false)
	expect(result[1] == &"go", "holding resolves the gate")
	director.cancel()
	hold.beats[0].gate.options[0].requires = &"key_item"
	director.begin(hold, null, acquire, release)
	expect(director.results.get(&"one") == CADDirector.TIMEOUT, "gate with no available option falls through")
	director.cancel()
	director.flags = {&"key_item": true}
	director.begin(hold, null, acquire, release)
	expect(director.results.is_empty(), "flag makes the option available")
	director.cancel()

	expect(acquired == released.size() and released.count(&"cancelled") == 7, "release ran once per run")
	director.queue_free()

## one: gated on marker "gate" -> two / missed.  two: host-driven -> complete.
func two_beats() -> CADSequence:
	var option := CADOption.new()
	option.id = &"go"
	option.action = ACTION
	option.next = &"two"
	var gate := CADGate.new()
	gate.options = [option]
	gate.window_seconds = 0.3
	gate.timeout_next = &"missed"
	gate.open_marker = &"gate"
	var one := CADBeat.new()
	one.id = &"one"
	one.gate = gate
	one.watchdog_seconds = 0.6
	var two := CADBeat.new()
	two.id = &"two"
	two.next = &"complete"
	two.watchdog_seconds = 0.6
	var sequence := CADSequence.new()
	sequence.entry = &"one"
	sequence.beats = [one, two]
	sequence.outcomes = [&"complete", &"missed"]
	return sequence

# --- Example encounters through the shared host ------------------------------

func bar_tests() -> void:
	var game_camera := Camera2D.new()
	add_child(game_camera)
	game_camera.make_current()
	var stand_in := Node2D.new()
	add_child(stand_in)

	# Dodge, grab the stool, hold the shove.
	var demo := open(BAR, {&"stool_available": true})
	demo.stage.bind(&"Player", stand_in)
	expect(demo.start(), "bar fight validates and starts")
	var opened: Array = await demo.director.gate_opened
	expect(opened[0].id == &"windup" and get_viewport().get_camera_2d() == demo.stage.get_node("Close"),
		"timeline marker opened the dodge gate on the close shot")
	pad(JOY_BUTTON_A)
	opened = await demo.director.gate_opened
	expect(opened[0].id == &"counter" and option_ids(opened[1]) == "stool,back_off", "choice gate offers both options")
	expect(stand_in.global_position.distance_to(Vector2(430, 440)) < 1.0, "bound outside actor followed its slot")
	pad(JOY_BUTTON_X)
	opened = await demo.director.gate_opened
	expect(opened[0].id == &"shove", "prop beat leads to the hold gate")
	send(&"cad_a", true)
	var outcome: StringName = await demo.director.finished
	send(&"cad_a", false)
	expect(outcome == &"won" and joined(demo.director.trail) == "approach,windup,evade,counter,stool_block,shove,shove_win",
		"dodge > stool > held shove wins")
	expect(get_viewport().get_camera_2d() == game_camera, "game camera restored")
	await close(demo)

	# Miss the dodge, no stool in this bar.
	demo = open(BAR, {})
	demo.start()
	await demo.director.gate_opened
	opened = await demo.director.gate_opened
	expect(demo.director.results[&"windup"] == CADDirector.TIMEOUT and joined(demo.director.trail) == "approach,windup,hit,counter",
		"missed dodge plays the hit and carries on")
	expect(option_ids(opened[1]) == "back_off", "stool option hidden without its flag")
	expect(demo.stage.get_node("Player").position.distance_to(Vector2(430, 440)) < 1.0, "both branches end in the same pose")
	tap(&"cad_b")
	expect(await demo.director.finished == &"withdrew", "backing off ends the encounter")
	await close(demo)

	# Grab the stool but never hold.
	demo = open(BAR, {&"stool_available": true})
	demo.start()
	await demo.director.gate_opened
	tap(&"cad_dodge")
	await demo.director.gate_opened
	tap(&"cad_a")
	expect(await demo.director.finished == &"stalemate", "failed hold gives a third outcome")
	await close(demo)
	game_camera.free()
	stand_in.free()

func chase_tests() -> void:
	var demo := open(CHASE, {})
	var runner: Node2D = demo.stage.get_node("Runner")
	var jump_from := [0.0]
	demo.director.beat_started.connect(func(beat: CADBeat, _visit: int) -> void:
		if beat.id == &"jump":
			jump_from[0] = runner.position.x)
	expect(demo.start(), "chase validates and starts with the same host script")
	for action: StringName in [&"cad_a", &"cad_b", &"cad_up"]:
		await demo.director.gate_opened
		tap(action)
	expect(await demo.director.finished == &"escaped" and joined(demo.director.trail) == "run1,jump,run2,roll,run3,escape_high",
		"three gates cleared, high road taken")
	expect(absf(jump_from[0] - 700.0) < 1.0, "branch waited for the end of the run-up")
	await close(demo)

	demo = open(CHASE, {})
	demo.start()
	await demo.director.gate_opened
	await demo.director.gate_opened
	tap(&"cad_b")
	expect(await demo.director.finished == &"escaped" and joined(demo.director.trail) == "run1,stumble,run2,roll,run3,escape_low",
		"missed jump stumbles on, idle fork defaults to the low road")
	await close(demo)

	demo = open(CHASE, {})
	demo.start()
	await demo.director.gate_opened
	tap(&"cad_a")
	expect(await demo.director.finished == &"was_caught", "missed roll gets caught")
	await close(demo)

# --- Helpers -----------------------------------------------------------------

func open(scene: PackedScene, flags: Dictionary) -> Node:
	var demo := scene.instantiate()
	demo.autostart = false
	demo.flags = flags
	add_child(demo)
	return demo

func close(demo: Node) -> void:
	await get_tree().process_frame
	demo.free()

func send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(action: StringName) -> void:
	send(action, true)
	send(action, false)

func pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func joined(ids: Array) -> String:
	return ",".join(ids)

func option_ids(options: Array) -> String:
	return ",".join(options.map(func(option: CADOption) -> StringName: return option.id))

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
	print("PASS " if condition else "FAIL ", message)
