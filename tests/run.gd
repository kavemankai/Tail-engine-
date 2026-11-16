extends Node
## Headless checks. Run: godot --headless --path . res://tests/run.tscn
## Pass suite names after "--" to run a subset: -- cad story

const SUITES := ["cad", "story", "dialogue", "flow", "explore", "save", "validate"]

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var wanted := OS.get_cmdline_user_args()
	var failures := 0
	for suite_name: String in SUITES:
		var path := "res://tests/test_%s.gd" % suite_name
		if (not wanted.is_empty() and suite_name not in wanted) or not ResourceLoader.exists(path):
			continue
		print("== ", suite_name)
		var suite: TestSuite = load(path).new()
		add_child(suite)
		await suite.run()
		failures += suite.failures
		await get_tree().process_frame
		suite.free()
	print("FAILURES ", failures)
	get_tree().quit(0 if failures == 0 else 1)
