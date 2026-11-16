class_name CADInteractionRunner
extends RefCounted
## One spec / evaluator / result per acquisition. Gate timing is real active
## time, with timeout winning ties at the deadline. Manual clocks make tests
## deterministic. Run/visit tokens reject delayed input after retries/rewind.

signal resolved(result: CADResult)

var clock: CADClock
var router := CADInputRouter.new()
var last_result: CADResult
var run_id := 0
var visit_id := 0
var active := false
var _beat: StringName
var _gate: CADGate
var _spec: CADInteractionSpec
var _options: Array[CADOption] = []
var _handler: CADInteractionHandler
var _window := 0.0
var _last_tick := 0.0

func _init(time_source: Callable = Callable()) -> void:
	clock = CADClock.new(time_source)

func begin(gate: CADGate, offered: Array[CADOption], scale: float, run: int, visit: int, beat: StringName) -> bool:
	if active or gate == null or gate.interaction == null or not gate.interaction.validation_errors(gate.options, gate.window_seconds * scale).is_empty() \
			or not is_finite(scale) or scale <= 0.0:
		return false
	_gate = gate.duplicate(true)
	_spec = _gate.interaction
	# Assistance widens accuracy/chord tolerances without moving authored contact
	# instants or changing animation speed. Hold/neutral durations stay explicit.
	_spec.perfect_seconds *= scale
	_spec.success_seconds *= scale
	_spec.partial_seconds *= scale
	_spec.chord_seconds *= scale
	_options.clear()
	for option in offered:
		_options.append(option.duplicate(true))
	run_id = run
	visit_id = visit
	_beat = beat
	_window = gate.window_seconds * scale
	_last_tick = 0.0
	last_result = null
	clock.reset()
	router.configure(_spec.input_actions(_options), _spec.controller_device)
	match _spec.family:
		CADInteractionSpec.Family.GESTURE: _handler = CADGestureHandler.new()
		CADInteractionSpec.Family.CHOICE: _handler = CADChoiceHandler.new()
		CADInteractionSpec.Family.TIMING: _handler = CADTimingHandler.new()
		CADInteractionSpec.Family.PASSIVE: _handler = CADPassiveHandler.new()
	_handler.configure(_spec, _options)
	active = true
	if _spec.family == CADInteractionSpec.Family.PASSIVE and _spec.actions.any(
		func(action: StringName) -> bool: return Input.is_action_pressed(action)):
		_complete({"grade": &"miss"})
	elif _options.is_empty() or (_spec.family != CADInteractionSpec.Family.CHOICE and not _options.any(
		func(option: CADOption) -> bool: return option.id == _spec.option_id)):
		_complete({"grade": &"timeout"})
	return true

func input(event: InputEvent, run: int, visit: int) -> void:
	if not active or clock.paused or run != run_id or visit != visit_id:
		return
	tick()
	if not active:
		return
	for sample in router.route(event, clock.elapsed):
		var result := _handler.input(sample)
		if not result.is_empty():
			_complete(result)
			return

func tick() -> void:
	if not active or clock.paused:
		return
	var elapsed := clock.tick()
	# Evaluate continuous progress up to the deadline before expiring. A held
	# action that completed before a frame hitch still succeeds. Input edges at
	# the deadline remain late. Passive's completion at the deadline is explicit.
	var evaluation_time := minf(elapsed, _window - 0.0000001)
	var result := _handler.tick(evaluation_time, maxf(0.0, evaluation_time - _last_tick))
	_last_tick = evaluation_time
	if not result.is_empty():
		_complete(result)
	elif elapsed >= _window:
		_complete(_handler.timeout())

func marker(id: StringName, run: int, visit: int) -> bool:
	if not active or clock.paused or run != run_id or visit != visit_id:
		return false
	tick()
	return _handler.marker(id, clock.elapsed) if active else false

func suspend(value: bool) -> void:
	if not active or clock.paused == value:
		return
	clock.set_paused(value)
	if value:
		_handler.reset_input()
	else:
		router.configure(_spec.input_actions(_options), router.controller)

func cancel() -> void:
	if active:
		_complete({"grade": &"cancelled", "progress": _handler.progress})

func remaining() -> float:
	return maxf(0.0, _window - clock.elapsed)

func progress() -> float:
	return _handler.progress if _handler != null else 0.0

func _complete(data: Dictionary) -> void:
	if not active:
		return
	active = false
	var result := CADResult.new()
	result.challenge_id = _spec.id
	result.beat_id = _beat
	result.run_id = run_id
	result.visit_id = visit_id
	result.grade = data["grade"]
	result.option_id = data.get("option_id", &"")
	result.progress = clampf(data.get("progress", 0.0), 0.0, 1.0)
	result.timing_error_ms = data.get("timing_error_ms", 0.0)
	if result.grade != &"cancelled":
		result.route_id = _spec.routes.get(result.grade, _gate.timeout_next)
		if not _spec.routes.has(result.grade):
			for option in _options:
				if option.id == result.option_id:
					result.route_id = option.next
	last_result = result
	resolved.emit(result)
