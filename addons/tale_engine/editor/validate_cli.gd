extends Node
## Validates one episode in a real game process so the editor dock can show
## runtime-accurate problems. Run:
##   godot --headless --path . res://addons/tale_engine/editor/validate_cli.tscn -- res://path/episode.tres
## Prints one "PROBLEM: ..." line per issue and exits non-zero on any.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var episode := load(args[0]) as TEEpisode if not args.is_empty() and ResourceLoader.exists(args[0]) else null
	if episode == null:
		print("PROBLEM: not an episode resource: %s" % (args[0] if not args.is_empty() else "(none given)"))
		get_tree().quit(2)
		return
	var errors := TEValidator.check(episode)
	for problem in errors:
		print("PROBLEM: ", problem)
	print("DONE %d" % errors.size())
	get_tree().quit(0 if errors.is_empty() else 1)
