class_name CADResult
extends RefCounted
## One resolved interaction visit. to_dict() contains only bounded scalar data;
## the legacy director.results / Story.results mappings retain their old shape.

const GRADES: Array[StringName] = [&"perfect", &"success", &"partial", &"miss", &"timeout", &"restrained", &"cancelled"]

var challenge_id: StringName
var beat_id: StringName
var run_id := 0
var visit_id := 0
var option_id: StringName
var intent_id: StringName
var target_id: StringName
var grade: StringName
var route_id: StringName
var timing_error_ms := 0.0
var progress := 0.0

func to_dict() -> Dictionary:
	return {"challenge_id": String(challenge_id), "beat_id": String(beat_id),
		"run_id": run_id, "visit_id": visit_id, "option_id": String(option_id),
		"intent_id": String(intent_id), "target_id": String(target_id),
		"grade": String(grade), "route_id": String(route_id),
		"timing_error_ms": timing_error_ms, "progress": progress}
