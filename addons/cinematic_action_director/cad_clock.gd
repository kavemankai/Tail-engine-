class_name CADClock
extends RefCounted
## Monotonic active seconds, independent of Engine.time_scale. Inject a callable
## returning seconds for deterministic tests. Explicit pauses exclude wall time.

var elapsed := 0.0
var paused := false
var _source: Callable
var _last := 0.0

func _init(source: Callable = Callable()) -> void:
	_source = source
	reset()

func reset() -> void:
	elapsed = 0.0
	paused = false
	_last = _now()

func tick() -> float:
	var now := maxf(_last, _now())
	if not paused:
		elapsed += now - _last
	_last = now
	return elapsed

func set_paused(value: bool) -> void:
	tick()
	paused = value

func _now() -> float:
	return float(_source.call()) if _source.is_valid() else Time.get_ticks_usec() / 1000000.0
