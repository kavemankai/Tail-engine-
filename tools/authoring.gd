extends Node
## Headless authoring entry point. Paths after -- may be episodes or sequences.
## No arguments audits every lab episode; output is also available as JSON.

func _ready() -> void:
	audit.call_deferred()

func audit() -> void:
	var paths := OS.get_cmdline_user_args()
	var defaults := paths.is_empty()
	if defaults:
		paths = PackedStringArray(load("res://content/qte_lab/lab.gd").EXAMPLES.values())
	var reports: Array[Dictionary] = []
	var failures := 0
	for path in paths:
		if not ResourceLoader.exists(path):
			reports.append({"path": path, "errors": ["Resource does not exist."], "warnings": []})
			failures += 1
			continue
		var resource := load(path)
		var report := {"path": path, "errors": PackedStringArray(), "warnings": PackedStringArray(), "encounters": []}
		if resource is TEEpisode or (defaults and resource is CADSequence):
			var episode: TEEpisode = resource if resource is TEEpisode else load("res://content/qte_lab/lab.gd").episode_for(path)
			report.errors = TEValidator.check(episode)
			for step in episode.steps:
				if step != null and step.kind == TEStep.Kind.ENCOUNTER:
					var sequence: CADSequence = step.resolve_sequence()
					if sequence != null:
						var detail := CADAuthoringReport.inspect(sequence)
						# Episode validation already resolves inherited locations and
						# stage errors; standalone graph audit must not require a stage.
						detail.erase("errors")
						detail["step"] = String(step.id)
						report.encounters.append(detail)
						for warning in detail.warnings: report.warnings.append("%s: %s" % [step.id, warning])
		elif resource is CADSequence:
			# No stage is available here. Structural errors are authoritative;
			# stage/actor validation happens when embedded in a TEEpisode.
			report.errors = resource.validation_errors()
			var detail := CADAuthoringReport.inspect(resource)
			detail.erase("errors")
			report.encounters.append(detail)
			report.warnings = detail.warnings
		else:
			report.errors.append("Expected a TEEpisode or CADSequence.")
		failures += report.errors.size()
		reports.append(report)
	var directory := "res://build/logs"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory + "/authoring.json", FileAccess.WRITE)
	if file == null:
		push_error("Could not write authoring report.")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify({"schema": 1, "reports": reports}, "\t"))
	file.close()
	for report in reports:
		for problem in report.errors: print("AUTHORING ERROR ", report.path, ": ", problem)
		for warning in report.warnings: print("AUTHORING WARNING ", report.path, ": ", warning)
	print("AUTHORING ", reports.size(), " resources, ", failures, " errors")
	get_tree().quit(0 if failures == 0 else 1)
