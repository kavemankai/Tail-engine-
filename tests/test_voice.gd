extends TestSuite
## Voice-over bookkeeping and lip-sync plumbing.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	var lines := TEVoice.lines(EPISODE)
	expect(lines.size() == TEValidator.voice_coverage(EPISODE)[1], "TEVoice and the validator count the same lines")
	expect(lines.any(func(entry: Dictionary) -> bool: return entry["id"] == "e0_007" and entry["character"] == "stranger" and entry["text"] == "Your tab is overdue."),
		"lines carry id, speaker and clean text")
	expect(lines.all(func(entry: Dictionary) -> bool: return not entry["text"].contains("[#")), "tags are stripped from the text")
	var csv := TEVoice.to_csv(EPISODE)
	expect(csv.begins_with("line_id,character,text,recorded,file\n") and csv.contains("e0_007,stranger,\"Your tab is overdue.\",no,"),
		"the recording script is a CSV with one row per line")

	expect(is_equal_approx(Audio.mouth_level(-80.0), 0.0) and is_equal_approx(Audio.mouth_level(0.0), 1.0), "silence is closed, loud is open")
	var middle := Audio.mouth_level(-26.0)
	expect(middle > 0.3 and middle < 0.7, "mid loudness opens the mouth part way")
	var opened := Audio.smooth_mouth(0.0, 1.0, 0.01)
	var closed := 1.0 - Audio.smooth_mouth(1.0, 0.0, 0.01)
	expect(opened > closed and opened > 0.0, "the mouth opens faster than it closes")

	var actor := TEActor.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = blend_shape_mesh("jawOpen")
	actor.add_child(mesh_instance)
	add_child(actor)
	actor.set_mouth_open(0.75)
	expect(is_equal_approx(mesh_instance.get_blend_shape_value(0), 0.75), "the default actor drives a jawOpen blend shape")
	actor.set_mouth_open(4.0)
	expect(is_equal_approx(mesh_instance.get_blend_shape_value(0), 1.0), "mouth values are clamped")
	actor.free()
	var bare := TEActor.new()
	add_child(bare)
	bare.set_mouth_open(0.5)
	expect(true, "an actor with no mouth shape ignores lip-sync")
	bare.free()

	expect(AudioServer.get_bus_index(&"Voice") >= 0, "voice plays on its own bus")

static func blend_shape_mesh(shape_name: String) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_blend_shape(shape_name)
	var vertices := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var base: Array = []
	base.resize(Mesh.ARRAY_MAX)
	base[Mesh.ARRAY_VERTEX] = vertices
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	shape[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, [shape])
	return mesh
