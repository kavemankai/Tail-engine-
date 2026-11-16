class_name CADStage
extends Node
## Root of an encounter scene. Timelines animate its child nodes ("slots") by
## name, so the scene and its timelines work wherever the stage is instanced.
## Bind a game actor to a slot and it follows the slot while the encounter runs.
## Method tracks on the stage call marker(), act() and cut().

@export var timelines: AnimationPlayer
@export var target_registry: CADTargetRegistry
@export var barks: Array[CADBark] = []
signal bark_requested(cue: CADBark, visit: int)
var _barks_seen: Dictionary = {}

var playback := CADPlaybackScope.new()
var _base_timeline_speed := 1.0

var prop_attachments := CADPropAttachments.new()

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
func bind(role: StringName, actor: Node) -> bool:
	if not is_instance_valid(actor) or (_director != null and playback.scale != 1.0 and not CADPlaybackScope.supported(actor)):
		return false
	unbind(role)
	_bound[role] = actor
	if _director != null:
		playback.add(actor)
		_attach(role)
	return true

func unbind(role: StringName) -> void:
	if _bound.has(role):
		playback.remove(_bound[role])
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

## One bark ID per visit, even when a waiting timeline loops.
func bark(id: StringName) -> bool:
	if _director == null or not _director.active() or _barks_seen.has(id):
		return false
	for cue in barks:
		if cue != null and cue.id == id:
			_barks_seen[id] = true
			_director.trace_event(&"bark", {"cue": id, "speaker": cue.speaker})
			bark_requested.emit(cue, _visit)
			return true
	return false

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
	if _director != null:
		_director.trace_event(&"camera", {"role": role})
	if camera not in _used_cameras:
		_used_cameras.append(camera)

## Authored contact markers. The offset at contact is retained without a snap.
func attach_prop(target_id: StringName, role: StringName, socket_path: NodePath) -> bool:
	if not is_instance_valid(target_registry):
		return false
	var target_actor := actor(role)
	var socket := target_actor.get_node_or_null(socket_path) as Node3D if is_instance_valid(target_actor) else null
	var attached := prop_attachments.attach(target_registry.target(target_id), socket)
	if attached and _director != null:
		_director.trace_event(&"prop_attach", {"prop": target_id, "role": role})
	if attached and _director != null and _director.context.prop_states.has(target_id):
		_director.context.prop_states[target_id] = false
	return attached

func detach_prop(target_id: StringName) -> bool:
	var detached := prop_attachments.detach(target_registry.target(target_id)) if is_instance_valid(target_registry) else false
	if detached and _director != null:
		_director.trace_event(&"prop_detach", {"prop": target_id})
	if detached and _director != null and _director.context.prop_states.has(target_id):
		_director.context.prop_states[target_id] = true
	return detached

## Selected IDs come from the runner result, never a UI widget or Story flag.
func attach_selected_prop(result_beat: StringName, role: StringName, socket_path: NodePath) -> bool:
	var result := _selected_target(result_beat)
	return attach_prop(result, role, socket_path) if result != &"" else false

func detach_selected_prop(result_beat: StringName) -> bool:
	var result := _selected_target(result_beat)
	return detach_prop(result) if result != &"" else false

func _selected_target(result_beat: StringName) -> StringName:
	if _director == null or not _director.detailed_results.has(result_beat):
		return &""
	return _director.detailed_results[result_beat].target_id

# --- Used by CADDirector --------------------------------------------------

func validation_errors(sequence: CADSequence) -> PackedStringArray:
	var errors := PackedStringArray()
	var bark_ids: Dictionary = {}
	for cue in barks:
		if cue == null:
			errors.append("Stage contains an empty bark.")
			continue
		errors.append_array(cue.validation_errors())
		if bark_ids.has(cue.id) or actor(cue.speaker) == null:
			errors.append("Bark %s has a duplicate ID or missing speaker role." % cue.id)
		bark_ids[cue.id] = true
	if target_registry != null:
		errors.append_array(target_registry.validation_errors(target_registry.targets.keys()))
	for role in sequence.actor_statuses:
		if actor(role) == null:
			errors.append("Context references missing actor role '%s'." % role)
	if not sequence.prop_states.is_empty():
		if target_registry == null:
			errors.append("Prop context requires a target registry.")
		else:
			errors.append_array(target_registry.validation_errors(sequence.prop_states.keys()))
	if sequence.beats.any(func(beat: CADBeat) -> bool: return beat != null and beat.playback_scale != 1.0):
		if timelines != null and (not is_finite(timelines.speed_scale) or timelines.speed_scale <= 0.0):
			errors.append("Slowdown needs positive finite base timeline speed.")
		for role in _bound:
			var node: Node = _bound[role]
			if is_instance_valid(node):
				if not CADPlaybackScope.supported(node):
					errors.append("Role %s needs a cinematic playback adapter." % role)
				else:
					var speed: float = node.speed_scale if node is AnimationPlayer else node.call(&"cad_playback_speed")
					if not is_finite(speed) or speed <= 0.0:
						errors.append("Role %s needs positive finite base playback speed." % role)
	for beat in sequence.beats:
		if beat != null and beat.gate != null and beat.gate.interaction != null and beat.gate.interaction.family == CADInteractionSpec.Family.TARGET:
			if target_registry == null:
				errors.append("Beat %s: Target requires a target_registry." % beat.id)
			else:
				errors.append_array(target_registry.validation_errors(beat.gate.interaction.target_options.keys()))
		if beat == null or beat.timeline == &"":
			continue
		if timelines == null or not timelines.has_animation(beat.timeline):
			errors.append("Beat %s: missing timeline '%s'." % [beat.id, beat.timeline])
			continue
		var animation := timelines.get_animation(beat.timeline)
		var gate := beat.gate
		if animation.loop_mode != Animation.LOOP_NONE and (gate == null or not gate.cut_on_resolve):
			errors.append("Beat %s: a looping timeline needs a gate that cuts on resolve." % beat.id)
		errors.append_array(_attachment_errors(animation, sequence))
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
			if entry[0] == &"bark" and not bark_ids.has(entry[1]):
				errors.append("Beat %s references missing bark %s." % [beat.id, entry[1]])
			if entry[0] in [&"act", &"cut"] and actor(entry[1]) == null:
				errors.append("Beat %s: timeline '%s' uses missing role '%s'." % [beat.id, beat.timeline, entry[1]])
	return errors

func timeline_length(timeline: StringName) -> float:
	return timelines.get_animation(timeline).length

func base_timeline_speed() -> float:
	return _base_timeline_speed

func set_playback_scale(scale: float) -> void:
	playback.set_scale(scale)

func acquire(director: CADDirector) -> void:
	_director = director
	_base_timeline_speed = timelines.speed_scale if timelines != null else 1.0
	playback.add(timelines)
	for bound: Node in _bound.values():
		playback.add(bound)
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
	_barks_seen.clear()
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

func release(cancelled := true) -> void:
	playback.clear()
	prop_attachments.release(cancelled)
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

func _exit_tree() -> void:
	playback.clear()
	prop_attachments.release(true)

func _attachment_errors(animation: Animation, sequence: CADSequence) -> PackedStringArray:
	var errors := PackedStringArray()
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key in animation.track_get_key_count(track):
			var method := animation.method_track_get_name(track, key)
			if method not in [&"attach_prop", &"detach_prop", &"attach_selected_prop", &"detach_selected_prop"]:
				continue
			var args := animation.method_track_get_params(track, key)
			if args.size() != (3 if method in [&"attach_prop", &"attach_selected_prop"] else 1):
				errors.append("Timeline %s: %s has invalid arguments." % [animation.resource_name, method])
				continue
			if (args[0] is not String and args[0] is not StringName) or (args.size() == 3 and (
					(args[1] is not String and args[1] is not StringName) or (args[2] is not NodePath and args[2] is not String))):
				errors.append("Timeline %s: %s arguments need target/result ID, role ID and socket NodePath." % [animation.resource_name, method])
				continue
			var selected := method in [&"attach_selected_prop", &"detach_selected_prop"]
			if selected:
				if not sequence.beats.any(func(beat: CADBeat) -> bool: return beat != null and beat.id == StringName(args[0]) and beat.gate != null and beat.gate.interaction != null and beat.gate.interaction.family == CADInteractionSpec.Family.TARGET):
					errors.append("Timeline %s: missing Target result beat '%s'." % [animation.resource_name, args[0]])
			elif target_registry == null or target_registry.target(StringName(args[0])) == null:
				errors.append("Timeline %s: attachment target '%s' is not bound." % [animation.resource_name, args[0]])
			if method in [&"attach_prop", &"attach_selected_prop"]:
				var role := StringName(args[1])
				var target_actor := actor(role)
				if target_actor == null or (_bound.has(role) and target_actor.get_node_or_null(NodePath(args[2])) is not Node3D):
					errors.append("Timeline %s: missing attachment role/socket '%s/%s'." % [animation.resource_name, role, args[2]])
	return errors
