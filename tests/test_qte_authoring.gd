extends "res://tests/test_interaction.gd"

func run() -> void:
	trace_contract()
	graph_contract()
	await debug_contract()

func trace_contract() -> void:
	var trace := CADTrace.new()
	trace.capacity = 3
	trace.time_source = func() -> float: return now[0]
	trace.reset(9)
	expect(not trace.record(&"disabled"), "trace is opt-in and records nothing by default")
	trace.enabled = true
	for i in 5:
		now[0] = i * 0.1
		expect(trace.record(&"sample", {"value": i}), "scalar trace event accepted")
	var snapshot := trace.snapshot()
	expect(snapshot.events.size() == 3 and snapshot.dropped == 2 and snapshot.events[0].index == 3, "trace evicts oldest events at its bounded capacity")
	snapshot.events[0].data.value = 99
	expect(trace.snapshot().events[0].data.value == 2, "trace snapshots cannot mutate recorded events")
	now[0] = 0.1
	trace.record(&"backwards")
	expect(is_equal_approx(trace.snapshot().events[-1].seconds, 0.4), "trace timestamps never move backwards")
	expect(not trace.record(&"invalid", {"node": self}) and not trace.last_error.is_empty(), "trace rejects scene references with an explicit error")
	expect(not trace.record(&"invalid", {"value": NAN}), "trace rejects nonfinite diagnostic values")
	var path := "user://trace_test_%s.json" % get_instance_id()
	expect(trace.write_json(path), "trace exports a bounded JSON artifact")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	expect(data.schema == 1 and data.events.size() == 3 and data.run_id == 9, "export contains scalar event history and run identity")
	DirAccess.remove_absolute(path)
	expect(not trace.write_json("res://bad_trace.json"), "runtime trace export stays in the user-data directory")
	var director := CADDirector.new()
	add_child(director)
	director.clock_source = func() -> float: return now[0]
	director.trace.enabled = true
	now[0] = 0.0
	director.begin(sequence(gate()))
	director.suspend(true)
	director.suspend(false)
	director._input(edge())
	director._input(edge())
	director._process(0)
	var kinds: Array = director.trace.snapshot().events.map(func(event: Dictionary) -> String: return event.event)
	expect(kinds.count("result") == 1 and kinds.count("finish") == 1 and "gate_open" in kinds and "input" in kinds, "director trace preserves exactly-once result/finish and mapped input lifecycle")
	expect("pause" in kinds and "resume" in kinds, "trace distinguishes suspended and active time transitions")
	director.begin(sequence(gate()))
	expect(director.trace.snapshot().run_id == 2 and director.trace.snapshot().events[0].event == "begin", "restart starts a fresh trace with a new run identity")
	director.cancel()
	director.free()

func graph_contract() -> void:
	var graph := sequence(gate())
	var report := CADAuthoringReport.inspect(graph)
	expect(report.errors.is_empty() and report.warnings.is_empty() and report.gates == 1 and report.families == PackedStringArray(["GESTURE"]), "authoring report describes a valid reusable interaction")
	var orphan := CADBeat.new()
	orphan.id = &"unused"
	orphan.next = &"won"
	orphan.watchdog_seconds = 1.0
	graph.beats.append(orphan)
	report = CADAuthoringReport.inspect(graph)
	expect("Unreachable beat: unused" in report.warnings and report.errors.is_empty(), "unreachable content is a conservative warning without changing compatibility")
	orphan.next = orphan.id
	report = CADAuthoringReport.inspect(graph)
	expect("ungated cycle" in "\n".join(report.warnings), "authoring audit flags possible automatic cycles instead of waiting forever")
	graph.beats[0].gate.options[0].next = &"missing"
	expect(not CADAuthoringReport.inspect(graph).errors.is_empty(), "authoring report retains structural errors as failures")
	var native: CADSequence = load("res://content/qte_lab/cinematic/encounter.tres")
	var stage: CADStage = load("res://content/qte_lab/cinematic/stage.tscn").instantiate()
	add_child(stage)
	report = CADAuthoringReport.inspect(native, stage)
	expect(report.errors.is_empty() and report.warnings.is_empty() and report.gates == 2, "cinematic native encounter passes graph and stage authoring audit")
	stage.free()

func debug_contract() -> void:
	var debug := TEDebug.new()
	add_child(debug)
	debug._panel.show()
	debug._process(0)
	expect("Step:" in debug._info.text, "existing F3 debug panel remains functional without active QTE")
	debug.free()
	await frames(3)
