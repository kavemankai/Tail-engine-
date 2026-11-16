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

enum Gate { NONE, PENDING, OPEN, RESOLVED }

const TIMEOUT := &"timeout"
const DONE := &"done"
const VIEWPORT_OWNER := &"_cad_director_owner"
const WATCHDOG_MARGIN := 5.0

## Read by CADOption.requires. Set before or during an encounter.
var flags: Dictionary = {}
## Accessibility: multiplies every gate window.
var window_scale := 1.0
## True when the last real input came from a gamepad.
var using_pad := false
## Beat IDs entered during the current or last run, in order.
var trail: Array[StringName] = []
## Gate result per beat ID for the current or last run.
var results: Dictionary[StringName, StringName] = {}

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
var _buffered: Dictionary[StringName, float] = {}
var _pending_next: StringName
var _goto: StringName

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
	_suspended = false
	_goto = &""
	_active = true
	if _stage != null:
		_stage.acquire(self)
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
	if _active and _stage != null:
		_stage.pause(suspended)

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
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false
	if not _active or _suspended or _beat == null or _beat.gate == null:
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

func _process(delta: float) -> void:
	if not _active or _suspended:
		return
	if _goto == &"":
		_beat_time += delta
		if _gate == Gate.OPEN:
			_tick_gate(delta)
		if _active and _goto == &"" and _beat_time >= _watchdog:
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
	var hold := 0.0
	for option in _options:
		if option.hold_seconds <= 0.0:
			continue
		if Input.is_action_pressed(option.action):
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
	_timeline_done = false
	_gate = Gate.NONE if _beat.gate == null else Gate.PENDING
	_gate_elapsed = 0.0
	_options = []
	_held.clear()
	_buffered.clear()
	_pending_next = &""
	_watchdog = _watchdog_for(_beat)
	trail.append(id)
	var visit := _visit
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
		total += _stage.timeline_length(beat.timeline)
	if beat.gate != null:
		total += beat.gate.window_seconds * window_scale
		for option in beat.gate.options:
			total += option.hold_seconds
	return total

func _open_gate() -> void:
	var gate := _beat.gate
	_gate = Gate.OPEN
	_gate_elapsed = 0.0
	_options = []
	for option in gate.options:
		if flag_holds(option.requires):
			_options.append(option)
	if _options.is_empty():
		_resolve(TIMEOUT, gate.timeout_next)
		return
	var visit := _visit
	gate_opened.emit(_beat, _options, gate.window_seconds * window_scale)
	if not _active or visit != _visit or _gate != Gate.OPEN:
		return
	for option in _options:
		if option.hold_seconds <= 0.0 and _buffered.has(option.id) \
				and _beat_time - _buffered[option.id] <= gate.buffer_seconds:
			_resolve(option.id, option.next)
			return

func _resolve(result: StringName, next: StringName) -> void:
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
	if _beat.gate == null:
		if _timeline_done:
			_goto = _beat.next
			for branch in _beat.branches:
				if flag_holds(branch.requires):
					_goto = branch.next
					break
	elif _gate == Gate.RESOLVED and (_beat.gate.cut_on_resolve or _timeline_done):
		_goto = _pending_next

func _finish(outcome: StringName, notify := true) -> void:
	_busy = true
	var was_open := _gate == Gate.OPEN
	_active = false
	_gate = Gate.NONE
	_goto = &""
	_beat = null
	_beats = {}
	if was_open:
		gate_closed.emit()
	if is_instance_valid(_stage):
		_stage.release()
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
