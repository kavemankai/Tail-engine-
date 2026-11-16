extends Node
## Headless checks. Run: godot --headless --path . res://tests/run.tscn
## Pass suite names after "--" to run a subset: -- cad story

const SUITES := ["cad", "story", "dialogue", "flow", "explore", "save", "validate", "lifecycle", "settings", "interaction", "qte_timing", "qte_direction", "compounds"]

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var wanted := OS.get_cmdline_user_args()
	for name: String in wanted:
		if name not in SUITES:
			push_error("Unknown test suite: " + name)
			get_tree().quit(1)
			return
	var failures := 0
	var checks := 0
	for suite_name: String in SUITES:
		var path := "res://tests/test_%s.gd" % suite_name
		if not wanted.is_empty() and suite_name not in wanted:
			continue
		if not ResourceLoader.exists(path):
			push_error("Missing test suite: " + path)
			get_tree().quit(1)
			return
		print("== ", suite_name)
		var suite: TestSuite = load(path).new()
		add_child(suite)
		var watchdog := Timer.new()
		watchdog.one_shot = true
		watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
		watchdog.ignore_time_scale = true
		add_child(watchdog)
		watchdog.timeout.connect(func() -> void:
			push_error("Suite timed out: " + suite_name)
			get_tree().quit(1))
		watchdog.start(90)
		await suite.run()
		watchdog.stop()
		watchdog.queue_free()
		failures += suite.failures
		checks += suite.checks
		await get_tree().process_frame
		suite.free()
	# Drain cancelled frame waits before shutting down the engine.
	await get_tree().process_frame
	await get_tree().process_frame
	print("CHECKS ", checks, " FAILURES ", failures)
	get_tree().quit(0 if failures == 0 else 1)
