class_name CADStage
extends Node
## Root of an encounter scene. Timelines animate its child nodes ("slots") by
## name, so the scene and its timelines work wherever the stage is instanced.
## Bind a game actor to a slot and it follows the slot while the encounter runs.
## Method tracks on the stage call marker(), act() and cut().

@export var timelines: AnimationPlayer

var _director: CADDirector
var _visit := 0
var _current: StringName
var _was_playing := false
var _saved_mode := AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
var _bound: Dictionary[StringName, Node] = {}
var _remotes: Dictionary[StringName, Node] = {}
var _previous_cameras: Array[Node] = []
var _used_cameras: Array[Node] = []

func _ready() -> void:
	if timelines == null:
		for child in get_children():
			if child is AnimationPlayer:
				timelines = child
				break
	if timelines != null:
		timelines.animation_finished.connect(_on_timeline_finished)

## Make a node outside the stage follow the slot named `role`.
func bind(role: StringName, actor: Node) -> void:
	unbind(role)
	_bound[role] = actor
	if _director != null:
		_attach(role)

func unbind(role: StringName) -> void:
	_bound.erase(role)
	if _remotes.has(role):
		_remotes[role].queue_free()
		_remotes.erase(role)

## The bound actor for a role, or the slot itself.
func actor(role: StringName) -> Node:
	var bound: Node = _bound.get(role)
	return bound if is_instance_valid(bound) else slot(role)

func slot(role: StringName) -> Node:
	return get_node_or_null(NodePath(role))

# --- Called from method tracks -------------------------------------------

## Report a named point in the current timeline, such as &"gate" or &"done".
func marker(id: StringName) -> void:
	if _director != null:
		_director.marker(id, _visit)

## Play a clip on a role. The target may implement cad_act(clip), be an
## AnimationPlayer or audio player, or have an AnimationPlayer child.
func act(role: StringName, clip: StringName) -> void:
	var target := actor(role)
	if target == null:
		push_warning("CADStage: no role '%s'." % role)
	elif target.has_method(&"cad_act"):
		target.call(&"cad_act", clip)
	elif target is AnimationPlayer:
		target.play(clip)
	elif target is AudioStreamPlayer or target is AudioStreamPlayer2D or target is AudioStreamPlayer3D:
		target.call(&"play")
	else:
		var player := target.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		if player != null and player.has_animation(clip):
			player.play(clip)
		elif target != slot(role):
			# An empty slot ignores clips, so a stage can run without its cast.
			push_warning("CADStage: role '%s' cannot play '%s'." % [role, clip])

## Cut to a camera slot.
func cut(role: StringName) -> void:
	var camera := slot(role)
	if camera is Camera2D:
		camera.enabled = true
		camera.make_current()
	elif camera is Camera3D:
		camera.make_current()
	else:
		push_warning("CADStage: no camera '%s'." % role)
		return
	if camera not in _used_cameras:
		_used_cameras.append(camera)

# --- Used by CADDirector --------------------------------------------------

func validation_errors(sequence: CADSequence) -> PackedStringArray:
	var errors := PackedStringArray()
	for beat in sequence.beats:
		if beat == null or beat.timeline == &"":
			continue
		if timelines == null or not timelines.has_animation(beat.timeline):
			errors.append("Beat %s: missing timeline '%s'." % [beat.id, beat.timeline])
			continue
		var animation := timelines.get_animation(beat.timeline)
		var gate := beat.gate
		if animation.loop_mode != Animation.LOOP_NONE and (gate == null or not gate.cut_on_resolve):
			errors.append("Beat %s: a looping timeline needs a gate that cuts on resolve." % beat.id)
		var calls := _method_calls(animation)
		if gate != null and gate.open_marker != &"" and [&"marker", gate.open_marker] not in calls:
			errors.append("Beat %s: timeline '%s' has no '%s' marker." % [beat.id, beat.timeline, gate.open_marker])
		if gate != null and gate.interaction != null and gate.interaction.timing_marker != &"" \
				and [&"marker", gate.interaction.timing_marker] not in calls:
			errors.append("Beat %s: missing interaction timing marker '%s'." % [beat.id, gate.interaction.timing_marker])
		elif gate != null and gate.interaction != null and gate.interaction.timing_marker != &"":
			var opened := _marker_time(animation, gate.open_marker) if gate.open_marker != &"" else 0.0
			var anchored := _marker_time(animation, gate.interaction.timing_marker)
			if anchored <= opened or anchored - opened + gate.interaction.ideal_seconds >= gate.window_seconds:
				errors.append("Beat %s: timing marker/ideal must follow opening and fit inside the gate window." % beat.id)
		for entry in calls:
			if entry[0] in [&"act", &"cut"] and actor(entry[1]) == null:
				errors.append("Beat %s: timeline '%s' uses missing role '%s'." % [beat.id, beat.timeline, entry[1]])
	return errors

func timeline_length(timeline: StringName) -> float:
	return timelines.get_animation(timeline).length

func acquire(director: CADDirector) -> void:
	_director = director
	_previous_cameras = [get_viewport().get_camera_2d(), get_viewport().get_camera_3d()]
	_used_cameras.clear()
	if timelines != null:
		# Deferred calls could arrive after the director has moved to another beat.
		_saved_mode = timelines.callback_mode_method
		timelines.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	for role in _bound:
		_attach(role)

func play(timeline: StringName, blend: float, visit: int) -> bool:
	if timelines == null or not timelines.has_animation(timeline):
		return false
	_visit = visit
	if _current == timeline:
		timelines.stop(true)
	# Godot drops method keys at time zero when it blends in from another
	# animation, so those are called here.
	var blending := blend > 0.0 and _current != &"" and _current != timeline
	_current = timeline
	timelines.play(timeline, blend)
	if blending:
		_call_keys_at_start(timelines.get_animation(timeline))
	return true

func pause(paused: bool) -> void:
	if timelines == null:
		return
	if paused:
		_was_playing = timelines.is_playing()
		timelines.pause()
	elif _was_playing:
		timelines.play()

func release() -> void:
	_director = null
	_current = &""
	if timelines != null:
		timelines.stop(true)
		timelines.callback_mode_method = _saved_mode
	for remote in _remotes.values():
		remote.queue_free()
	_remotes.clear()
	# Hand the view back. With no earlier camera, the last shot stays.
	var restored := false
	for camera in _previous_cameras:
		if is_instance_valid(camera) and camera not in _used_cameras:
			camera.call(&"make_current")
			restored = true
	if restored:
		for camera in _used_cameras:
			if camera is Camera2D:
				camera.enabled = false
			elif camera is Camera3D:
				camera.clear_current(false)
	_previous_cameras.clear()
	_used_cameras.clear()

func _attach(role: StringName) -> void:
	var from := slot(role)
	var to: Node = _bound.get(role)
	if _remotes.has(role) or from == null or not is_instance_valid(to):
		return
	var remote: Node
	if from is Node2D and to is Node2D:
		remote = RemoteTransform2D.new()
	elif from is Node3D and to is Node3D:
		remote = RemoteTransform3D.new()
	else:
		push_warning("CADStage: cannot bind role '%s' to %s." % [role, to])
		return
	from.add_child(remote)
	remote.set(&"remote_path", remote.get_path_to(to))
	_remotes[role] = remote

func _on_timeline_finished(timeline: StringName) -> void:
	if _director != null and timeline == _current:
		_director.marker(CADDirector.DONE, _visit)

func _call_keys_at_start(animation: Animation) -> void:
	var base := timelines.get_node_or_null(timelines.root_node)
	for track in animation.get_track_count():
		if base == null or animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		var target := base.get_node_or_null(animation.track_get_path(track))
		for key in animation.track_get_key_count(track):
			if target != null and animation.track_get_key_time(track, key) <= 0.0:
				target.callv(animation.method_track_get_name(track, key), animation.method_track_get_params(track, key))

## Every method-track call in a timeline as [method, first argument].
func _method_calls(animation: Animation) -> Array:
	var calls := []
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in animation.track_get_key_count(track):
			var params := animation.method_track_get_params(track, key)
			calls.append([animation.method_track_get_name(track, key),
				StringName(params[0]) if not params.is_empty() else &""])
	return calls

func _marker_time(animation: Animation, marker_id: StringName) -> float:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in animation.track_get_key_count(track):
			if animation.method_track_get_name(track, key) == &"marker":
				var params := animation.method_track_get_params(track, key)
				if not params.is_empty() and params[0] == marker_id:
					return animation.track_get_key_time(track, key)
	return -1.0
