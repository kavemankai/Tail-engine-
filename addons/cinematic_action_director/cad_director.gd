class_name CADDirector
extends Node
## Runs a CADSequence. For each beat it plays the timeline on a CADStage, opens
## the gate, latches the player's result and follows the matching exit.
## A host without a stage drives beats itself through marker().

signal beat_started(beat: CADBeat, visit: int)
signal gate_opened(beat: CADBeat, options: Array[CADOption], window: float)
## `hold` is 0..1 progress of a held option, or 0.
signal gate_progress(remaining: float, hold: float)
signal gate_closed
signal gate_resolved(beat: CADBeat, result: StringName)
signal finished(outcome: StringName)
signal input_device_changed
signal interaction_resolved(result: CADResult)
signal suspension_changed(paused: bool)
## The controller that owned the open prompt was unplugged. The prompt stays
## open and any device may take it over; the host should pause the game.
signal controller_lost(device: int)

enum Gate { NONE, PENDING, OPEN, RESOLVED }

const TIMEOUT := &"timeout"
const DONE := &"done"
const VIEWPORT_OWNER := &"_cad_director_owner"
const WATCHDOG_MARGIN := 5.0

## Read by CADOption.requires. Set before or during an encounter.
var flags: Dictionary = {}
## Accessibility: multiplies every gate window.
var window_scale := 1.0
## Accessibility: skill prompts (one option, or a v2 skill family) succeed by
## themselves shortly after opening. Choices between options still wait.
var auto_complete := false
## Accessibility: a hold prompt latches on the first press and lets go on the
## second, so nothing needs to be held down.
var hold_toggle := false
## Seconds after a gate opens before auto-complete resolves it, at most half
## the window.
const AUTO_SECONDS := 0.35
## True when the last real input came from a gamepad.
var using_pad: bool:
	get:
		return CADInputDevice.using_pad
	set(value):
		CADInputDevice.set_device(value)
## Retains synchronous terminal results, including cancellation in begin hooks.
var last_outcome: StringName
## Beat IDs entered during the current or last run, in order.
var trail: Array[StringName] = []
## Gate result per beat ID for the current or last run.
var results: Dictionary[StringName, StringName] = {}
## Additive typed detail; never changes the legacy results or save-file shape.
var detailed_results: Dictionary[StringName, CADResult] = {}
var trace := CADTrace.new()
var _trace_paused := false
var context := CADEncounterContext.new()
var _resolved_visits: Dictionary = {}
var interaction_runner: CADInteractionRunner
## Optional deterministic seconds source; leave empty for real active time.
var clock_source: Callable
## Optional held-event provider for deterministic directional acquisition tests.
var input_snapshot: Callable

var _active := false
var _busy := false
var _suspended := false
var _beats: Dictionary[StringName, CADBeat] = {}
var _outcomes: Array[StringName] = []
var _stage: CADStage
var _viewport: Viewport
var _release: Callable
var _beat: CADBeat
var _visit := 0
var _beat_time := 0.0
var _watchdog := 0.0
var _timeline_done := false
var _gate := Gate.NONE
var _gate_elapsed := 0.0
var _options: Array[CADOption] = []
var _held: Dictionary[StringName, float] = {}
## Hold options latched on by hold_toggle.
var _latched: Dictionary[StringName, bool] = {}
var _buffered: Dictionary[StringName, float] = {}
var _pending_next: StringName
var _goto: StringName
var _display_pad := false
var _run_id := 0
var _beat_clock: CADClock

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and _active:
		_pause_interaction_clocks(_suspended or get_tree().paused)

static func validation_errors(sequence: CADSequence, stage: CADStage = null) -> PackedStringArray:
	var errors := sequence.validation_errors()
	for beat in sequence.beats:
		if beat == null:
			continue
		if beat.timeline != &"" and stage == null:
			errors.append("Beat %s has a timeline but no stage was given." % beat.id)
		if beat.gate != null:
			for option in beat.gate.options:
				if option != null and not InputMap.has_action(option.action):
					errors.append("Missing InputMap action: %s" % option.action)
	if stage == null and sequence.beats.any(func(beat: CADBeat) -> bool: return beat != null and beat.playback_scale != 1.0):
		errors.append("Local cinematic speed requires a stage.")
	if stage != null:
		errors.append_array(stage.validation_errors(sequence))
	return errors

## Start an encounter. `acquire` returns true once the host has given up
## control; `release` receives the outcome and runs exactly once per run.
func begin(sequence: CADSequence, stage: CADStage = null,
		acquire: Callable = Callable(), release: Callable = Callable()) -> bool:
	if _active or _busy or sequence == null or not is_inside_tree():
		return false
	var viewport := get_viewport()
	if viewport.has_meta(VIEWPORT_OWNER):
		return false
	var errors := validation_errors(sequence, stage)
	if sequence.beats.any(func(beat: CADBeat) -> bool: return beat != null and beat.gate != null and beat.gate.interaction != null) \
			and (not is_finite(window_scale) or window_scale <= 0.0):
		errors.append("Interaction timing scale must be finite and positive.")
	if not errors.is_empty():
		push_warning("Invalid cinematic sequence: " + "; ".join(errors))
		return false
	_busy = true
	viewport.set_meta(VIEWPORT_OWNER, true)
	var acquired: bool = not acquire.is_valid() or acquire.call() == true
	_busy = false
	if not acquired or not is_inside_tree():
		if is_instance_valid(viewport):
			viewport.remove_meta(VIEWPORT_OWNER)
		if acquired and release.is_valid():
			release.call(&"cancelled")
		return false
	_viewport = viewport
	_stage = stage
	_release = release
	_beats = {}
	for beat in sequence.beats:
		_beats[beat.id] = beat
	_outcomes = sequence.outcomes.duplicate()
	trail = []
	results = {}
	detailed_results = {}
	_resolved_visits.clear()
	context = CADEncounterContext.new()
	context.configure(sequence)
	if stage != null and stage.target_registry != null:
		for id in context.prop_states:
			context.prop_states[id] = context.prop_states[id] and stage.target_registry.available(id, flags)
	interaction_runner = null
	_run_id += 1
	trace.reset(_run_id)
	_trace_paused = false
	_suspended = false
	_goto = &""
	_active = true
	last_outcome = &""
	if _stage != null:
		_stage.acquire(self)
	trace_event(&"begin", {"entry": sequence.entry})
	_enter(sequence.entry)
	return true

## Report a point in the current beat. `visit` is the number beat_started gave;
## a marker carrying an older number is rejected. &"done" completes the
## timeline, and the gate's open_marker opens the gate.
func marker(id: StringName, visit: int) -> bool:
	if not _active or _suspended or visit != _visit or _goto != &"":
		return false
	if id == DONE:
		if _timeline_done:
			return false
		_timeline_done = true
		if _gate == Gate.PENDING:
			_open_gate()
		_check_complete()
		return true
	if _gate == Gate.OPEN and interaction_runner != null and interaction_runner.active:
		if interaction_runner.marker(id, _run_id, visit):
			return true
	if _gate == Gate.PENDING and id == _beat.gate.open_marker:
		_open_gate()
		return true
	return false

func cancel() -> void:
	if _active:
		_finish(&"cancelled")

## Freeze the gate clock, the watchdog and the stage timeline, and ignore
## input and markers until resumed.
func suspend(suspended: bool) -> void:
	if suspended == _suspended:
		return
	_suspended = suspended
	_pause_interaction_clocks(suspended or get_tree().paused)
	if _active and _stage != null:
		_stage.pause(suspended)

func trace_event(kind: StringName, fields: Dictionary = {}) -> void:
	if trace.enabled:
		var data := fields.duplicate()
		data["visit_id"] = _visit
		data["beat_id"] = _beat.id if _beat != null else &""
		trace.record(kind, data)

func record() -> Dictionary:
	var records := {}
	for id in detailed_results:
		records[String(id)] = detailed_results[id].to_dict()
	return {"schema": 1, "results": records, "context": context.to_dict()}

## Run counter; increases with every begin(). Stale callbacks compare it.
func run_id() -> int:
	return _run_id

## Beat visit counter within the run.
func visit() -> int:
	return _visit

## The beat playing now, or null.
func current_beat() -> CADBeat:
	return _beat

## The stage this run plays on, or null.
func stage() -> CADStage:
	return _stage

func input_suspended() -> bool:
	return _suspended or get_tree().paused

func active() -> bool:
	return _active

## True for an empty name, a truthy flag, or "!name" with a falsy flag.
func flag_holds(name: StringName) -> bool:
	var text := String(name)
	if text == "":
		return true
	if text.begins_with("!"):
		return not flags.get(StringName(text.substr(1)), false)
	return true if flags.get(name, false) else false

func _input(event: InputEvent) -> void:
	CADInputDevice.observe(event)
	if not _active or _suspended or _beat == null or _beat.gate == null:
		return
	_trace_input(event)
	if _beat.gate.interaction != null:
		if _gate == Gate.OPEN and interaction_runner != null:
			if interaction_runner.router.relevant(event):
				get_viewport().set_input_as_handled()
			interaction_runner.input(event, _run_id, _visit)
		return
	if _gate == Gate.PENDING:
		for option in _beat.gate.options:
			if event.is_action_pressed(option.action):
				_buffered[option.id] = _beat_time
	elif _gate == Gate.OPEN:
		for option in _options:
			if option.hold_seconds <= 0.0 and event.is_action_pressed(option.action):
				get_viewport().set_input_as_handled()
				_resolve(option.id, option.next)
				return
			if option.hold_seconds > 0.0 and hold_toggle and event.is_action_pressed(option.action) and not event.is_echo():
				get_viewport().set_input_as_handled()
				_latched[option.id] = not _latched.get(option.id, false)

func _process(delta: float) -> void:
	if _display_pad != using_pad:
		_display_pad = using_pad
		input_device_changed.emit()
	if not _active or _suspended:
		return
	if _goto == &"":
		_beat_time += delta
		if _gate == Gate.OPEN:
			_tick_gate(delta)
		var watch_time := _beat_clock.tick() if _beat != null and _beat.gate != null and _beat.gate.interaction != null else _beat_time
		if _active and _goto == &"" and watch_time >= _watchdog:
			_finish(&"watchdog")
			return
	if _active and _goto != &"":
		var destination := _goto
		_goto = &""
		if destination in _outcomes:
			_finish(destination)
		else:
			_enter(destination)

func _tick_gate(delta: float) -> void:
	if _beat.gate.interaction != null:
		var runner := interaction_runner
		runner.tick()
		if _active and _gate == Gate.OPEN and runner == interaction_runner:
			gate_progress.emit(runner.remaining(), runner.progress())
		return
	if auto_complete and _options.size() == 1:
		var at := minf(AUTO_SECONDS, _beat.gate.window_seconds * window_scale * 0.5)
		if _gate_elapsed + delta >= at:
			_resolve(_options[0].id, _options[0].next)
			return
	var hold := 0.0
	for option in _options:
		if option.hold_seconds <= 0.0:
			continue
		var down: bool = _latched.get(option.id, false) if hold_toggle else Input.is_action_pressed(option.action)
		if down:
			_held[option.id] = _held.get(option.id, 0.0) + delta
			if _held[option.id] >= option.hold_seconds:
				_resolve(option.id, option.next)
				return
			hold = maxf(hold, _held[option.id] / option.hold_seconds)
		else:
			_held[option.id] = 0.0
	# The window does not run out under a hold in progress.
	if hold <= 0.0:
		_gate_elapsed += delta
	var window := _beat.gate.window_seconds * window_scale
	if _gate_elapsed >= window:
		_resolve(TIMEOUT, _beat.gate.timeout_next)
	else:
		gate_progress.emit(window - _gate_elapsed, hold)

func _enter(id: StringName) -> void:
	_beat = _beats[id]
	_visit += 1
	_beat_time = 0.0
	_beat_clock = CADClock.new(clock_source)
	_beat_clock.set_paused(_suspended or get_tree().paused)
	_timeline_done = false
	_gate = Gate.NONE if _beat.gate == null else Gate.PENDING
	_gate_elapsed = 0.0
	_options = []
	_held.clear()
	_buffered.clear()
	_pending_next = &""
	_watchdog = _watchdog_for(_beat)
	trail.append(id)
	context.enter(_beat)
	if _stage != null:
		_stage.set_playback_scale(_beat.playback_scale)
	var visit := _visit
	trace_event(&"beat", {"timeline": _beat.timeline, "playback_scale": _beat.playback_scale, "momentum": context.momentum, "intent": context.intent})
	beat_started.emit(_beat, visit)
	if not _active or visit != _visit:
		return
	if _beat.timeline != &"" and not _stage.play(_beat.timeline, _beat.blend_seconds, visit):
		_finish(&"staging_error")
		return
	if _gate == Gate.PENDING and _beat.gate.open_marker == &"":
		_open_gate()

func _watchdog_for(beat: CADBeat) -> float:
	if beat.watchdog_seconds > 0.0:
		return beat.watchdog_seconds
	var total := WATCHDOG_MARGIN
	if beat.timeline != &"":
		total += _stage.timeline_length(beat.timeline) / (beat.playback_scale * maxf(0.001, _stage.base_timeline_speed()))
	if beat.gate != null:
		total += beat.gate.window_seconds * window_scale
		for option in beat.gate.options:
			total += option.hold_seconds
	return total

func _open_gate() -> void:
	var gate := _beat.gate
	_gate = Gate.OPEN
	_gate_elapsed = 0.0
	_latched.clear()
	_options = []
	for option in gate.options:
		if flag_holds(option.requires):
			_options.append(option)
	trace_event(&"gate_open", {"offered": _options.size(), "window": gate.window_seconds * window_scale, "family": _family_name(gate.interaction)})
	if _options.is_empty():
		_resolve(TIMEOUT, gate.timeout_next)
		return
	if gate.interaction != null:
		interaction_runner = CADInteractionRunner.new(clock_source, input_snapshot)
		interaction_runner.auto_complete = auto_complete
		interaction_runner.hold_toggle = hold_toggle
		interaction_runner.resolved.connect(_on_interaction_resolved)
		if not interaction_runner.begin(gate, _options, window_scale, _run_id, _visit, _beat.id, _interaction_context()):
			push_warning(interaction_runner.last_error)
			_finish(&"staging_error")
			return
		if not _active or _gate != Gate.OPEN:
			return
	var visit := _visit
	gate_opened.emit(_beat, _options, gate.window_seconds * window_scale)
	if not _active or visit != _visit or _gate != Gate.OPEN:
		return
	if gate.interaction != null:
		return
	for option in _options:
		if option.hold_seconds <= 0.0 and _buffered.has(option.id) \
				and _beat_time - _buffered[option.id] <= gate.buffer_seconds:
			_resolve(option.id, option.next)
			return

func _resolve(result: StringName, next: StringName) -> void:
	if not _active or _gate != Gate.OPEN:
		return
	trace_event(&"route", {"option": result, "next": next})
	_gate = Gate.RESOLVED
	_pending_next = next
	results[_beat.id] = result
	var visit := _visit
	gate_closed.emit()
	if _active and visit == _visit:
		gate_resolved.emit(_beat, result)
	if _active and visit == _visit:
		_check_complete()

func _check_complete() -> void:
	if is_instance_valid(_stage) and is_instance_valid(_stage.target_registry):
		for id in context.prop_states:
			context.prop_states[id] = context.prop_states[id] and _stage.target_registry.available(id, flags)
	if _beat.gate == null:
		if _timeline_done:
			_goto = _beat.next
			for branch in _beat.branches:
				if flag_holds(branch.requires) and (branch.predicate == null or branch.predicate.matches(context)):
					_goto = branch.next
					break
	elif _gate == Gate.RESOLVED and (_beat.gate.cut_on_resolve or _timeline_done):
		_goto = _pending_next

func _finish(outcome: StringName, notify := true) -> void:
	trace_event(&"finish", {"outcome": outcome, "momentum": context.momentum, "intent": context.intent})
	last_outcome = outcome
	_busy = true
	var was_open := _gate == Gate.OPEN
	_active = false
	_gate = Gate.NONE
	_goto = &""
	_beat = null
	if interaction_runner != null:
		interaction_runner.cancel()
	_beats = {}
	if was_open:
		gate_closed.emit()
	if is_instance_valid(_stage):
		_stage.release(outcome not in _outcomes)
	_stage = null
	var release := _release
	_release = Callable()
	if release.is_valid():
		release.call(outcome)
	if is_instance_valid(_viewport):
		_viewport.remove_meta(VIEWPORT_OWNER)
	_viewport = null
	_busy = false
	if notify:
		finished.emit(outcome)

func _exit_tree() -> void:
	if _active:
		_finish(&"cancelled", false)

func _on_interaction_resolved(result: CADResult) -> void:
	if not _active or result.run_id != _run_id or result.visit_id != _visit or _gate != Gate.OPEN:
		return
	if result.grade == &"cancelled" or _resolved_visits.has(result.visit_id):
		return
	_resolved_visits[result.visit_id] = true
	context.apply(result)
	trace_event(&"result", {"grade": result.grade, "option": result.option_id, "route": result.route_id, "intent": result.intent_id, "target": result.target_id, "momentum": context.momentum, "progress": result.progress, "timing_error_ms": result.timing_error_ms, "direction": result.direction})
	detailed_results[result.beat_id] = result
	interaction_resolved.emit(result)
	if _active and result.run_id == _run_id and result.visit_id == _visit:
		_resolve(result.option_id if result.option_id != &"" else TIMEOUT, result.route_id)

func _pause_interaction_clocks(paused: bool) -> void:
	if paused != _trace_paused:
		_trace_paused = paused
		trace_event(&"pause" if paused else &"resume")
	if _beat_clock != null:
		_beat_clock.set_paused(paused)
	if interaction_runner != null:
		interaction_runner.suspend(paused)
	suspension_changed.emit(paused)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and _active and interaction_runner != null and interaction_runner.active \
			and interaction_runner.router.controller == device:
		# Unplugging a pad must not cost the player the scene: free the prompt
		# for whichever device they pick up next and let the host pause.
		interaction_runner.router.controller = -1
		trace_event(&"controller_lost", {"device": device})
		controller_lost.emit(device)

func _target_snapshot() -> Array[Dictionary]:
	if not is_instance_valid(_stage) or not is_instance_valid(_stage.target_registry) or _beat == null or _beat.gate == null:
		return []
	return _stage.target_registry.snapshot(_beat.gate.interaction.target_options.keys(), flags)

func _interaction_context() -> Dictionary:
	var context := {}
	if is_instance_valid(_stage) and is_instance_valid(_stage.target_registry):
		context.target_snapshot = _target_snapshot
		var size := get_viewport().get_visible_rect().size
		context.target_extent = size / maxf(1.0, size.y)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var basis := camera.global_basis.orthonormalized()
		var forward := Vector2(-basis.z.x, -basis.z.z)
		if forward.is_zero_approx():
			var right := Vector2(basis.x.x, basis.x.z)
			forward = Vector2(right.y, -right.x)
		context.camera_forward = forward.normalized()
		return context
	var camera_2d := get_viewport().get_camera_2d()
	if camera_2d != null:
		context.camera_forward = Vector2.UP.rotated(camera_2d.global_rotation)
	return context

func _trace_input(event: InputEvent) -> void:
	if not trace.enabled:
		return
	var actions: Array[StringName] = []
	if _beat.gate.interaction != null:
		actions = _beat.gate.interaction.input_actions(_options)
	else:
		for option in _beat.gate.options:
			if option != null: actions.append(option.action)
	var matching := PackedStringArray()
	for action in actions:
		if event.is_action(action): matching.append(String(action))
	if not matching.is_empty():
		trace_event(&"input", {"actions": ",".join(matching), "pressed": event.is_pressed(), "device": event.device if event is InputEventJoypadButton or event is InputEventJoypadMotion else -1, "open": _gate == Gate.OPEN})

func _family_name(spec: CADInteractionSpec) -> String:
	return "legacy" if spec == null else (String(CADInteractionSpec.Family.keys()[spec.family]) if spec.family >= 0 and spec.family < CADInteractionSpec.Family.size() else "invalid")
