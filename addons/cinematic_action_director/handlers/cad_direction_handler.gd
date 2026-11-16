class_name CADDirectionHandler
extends CADInteractionHandler
## Fresh deflection, sustained directional block or sector-to-option selection.
## Pure evaluator; camera basis is a frozen planar vector supplied by the host.

var forward := Vector2.UP
var _holding := false
var _from := 0.0
var _needs_neutral := false
var _pending := false
var _candidate := -1
var _candidate_from := 0.0

func input(sample: CADInputSample) -> Dictionary:
	if sample.kind != CADInputSample.Kind.DIRECTION:
		return wrong() if sample.pressed else {}
	if not sample.pressed:
		_holding = false
		_needs_neutral = false
		progress = 0.0
		if spec.direction_mode == CADInteractionSpec.DirectionMode.HOLD:
			_pending = false
		return {}
	var vector := sample.vector
	if spec.direction_space == CADInteractionSpec.DirectionSpace.CAMERA:
		var right := Vector2(-forward.y, forward.x)
		vector = right * vector.x - forward * vector.y
	var sector := sector_of(vector, spec.direction_eight_way)
	if spec.direction_mode == CADInteractionSpec.DirectionMode.HOLD:
		if _holding and sector != spec.direction_sector:
			_holding = false
			progress = 0.0
			_needs_neutral = true
			return _wrong_direction(sector)
	if sample.started and not _needs_neutral:
		if not _pending:
			_candidate_from = sample.at
		_pending = true
	if _pending:
		_candidate = sector
		if spec.direction_settle_seconds == 0.0:
			return _decide(sample.at)
	return {}

func _decide(at: float) -> Dictionary:
	_pending = false
	var sector := _candidate
	if spec.direction_mode == CADInteractionSpec.DirectionMode.HOLD:
		if sector != spec.direction_sector:
			_needs_neutral = true
			return _wrong_direction(sector)
		_holding = true
		_from = at
		return {}
	var option_id := spec.option_id
	if spec.direction_mode == CADInteractionSpec.DirectionMode.SELECT:
		option_id = spec.direction_options.get(sector, &"")
	elif sector != spec.direction_sector:
		return _wrong_direction(sector)
	if option_id == &"" or not options.any(func(option: CADOption) -> bool: return option.id == option_id):
		return _wrong_direction(sector)
	return {"grade": &"success", "option_id": option_id, "direction": sector, "progress": 1.0}

func tick(elapsed: float, _delta: float) -> Dictionary:
	if _pending and elapsed >= _candidate_from + spec.direction_settle_seconds:
		var result := _decide(_candidate_from + spec.direction_settle_seconds)
		if not result.is_empty():
			return result
	if _holding:
		progress = clampf((elapsed - _from) / spec.hold_seconds, 0.0, 1.0)
		if progress >= 1.0:
			return {"grade": &"success", "option_id": spec.option_id, "direction": spec.direction_sector, "progress": 1.0}
	return {}

func reset_input() -> void:
	_holding = false
	_needs_neutral = false
	progress = 0.0
	_pending = false

func _wrong_direction(sector: int) -> Dictionary:
	var result := wrong()
	if not result.is_empty():
		result["direction"] = sector
	return result

static func sector_of(vector: Vector2, eight_way := false) -> int:
	if vector.is_zero_approx():
		return -1
	var count := 8 if eight_way else 4
	# Ties go clockwise; +Y is down in input space, +Z in world space.
	var angle := fposmod(atan2(vector.x, -vector.y), TAU)
	var index := int(floor((angle + PI / count) / (TAU / count))) % count
	return index if eight_way else index * 2

static func vector_of(sector: int) -> Vector2:
	return Vector2(sin(sector * PI / 4.0), -cos(sector * PI / 4.0))

static func input_sector(sector: int, camera_forward: Vector2, eight_way: bool) -> int:
	var vector := vector_of(sector)
	var right := Vector2(-camera_forward.y, camera_forward.x)
	return sector_of(Vector2(vector.dot(right), -vector.dot(camera_forward)), eight_way)
