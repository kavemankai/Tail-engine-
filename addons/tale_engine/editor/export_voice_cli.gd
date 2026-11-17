extends Node
## Writes a voice-over recording script (CSV) for an episode. Run:
##   godot --headless --path . res://addons/tale_engine/editor/export_voice_cli.tscn -- res://path/episode.tres out.csv

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var episode := load(args[0]) as TEEpisode if args.size() >= 2 and ResourceLoader.exists(args[0]) else null
	if episode == null:
		print("usage: -- <episode.tres> <out.csv>")
		get_tree().quit(2)
		return
	var file := FileAccess.open(args[1], FileAccess.WRITE)
	if file == null:
		print("cannot write %s" % args[1])
		get_tree().quit(1)
		return
	file.store_string(TEVoice.to_csv(episode))
	file.close()
	var coverage := TEVoice.coverage(episode)
	print("%d of %d lines recorded; script written to %s" % [coverage[0], coverage[1], args[1]])
	get_tree().quit(0)
