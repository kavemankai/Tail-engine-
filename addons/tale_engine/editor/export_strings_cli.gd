extends Node
## Writes a translation template (.pot) of engine and episode text. Run:
##   godot --headless --path . res://addons/tale_engine/editor/export_strings_cli.tscn -- out.pot res://path/episode.tres [more episodes or a season.tres]
## Dialogue lines are not included: add the .dialogue files to the project's
## POT list (Project Settings > Localization > POT Generation) for those.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <out.pot> [episode.tres | season.tres ...]")
		get_tree().quit(2)
		return
	var sources := {"Tale Engine interface": TEStrings.engine()}
	for path: String in args.slice(1):
		var resource := load(path) if ResourceLoader.exists(path) else null
		var episodes: Array = []
		if resource is TESeason:
			sources["Season " + path] = PackedStringArray([resource.title]) if resource.title != "" else PackedStringArray()
			episodes = resource.episodes
		elif resource is TEEpisode:
			episodes = [resource]
		else:
			print("not an episode or season: %s" % path)
			get_tree().quit(2)
			return
		for episode: TEEpisode in episodes:
			sources["Episode " + (episode.resource_path if episode.resource_path != "" else String(episode.id))] = TEStrings.content(episode)
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		print("cannot write %s" % args[0])
		get_tree().quit(1)
		return
	file.store_string(TEStrings.to_pot(sources))
	file.close()
	var total := 0
	for strings: PackedStringArray in sources.values():
		total += strings.size()
	print("%d strings written to %s" % [total, args[0]])
	get_tree().quit(0)
