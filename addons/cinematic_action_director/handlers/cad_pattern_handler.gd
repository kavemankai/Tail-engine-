class_name CADPatternHandler
extends CADInteractionHandler
## One ordered list, including alternation. Router owns debounce/rearm/sources;
## this evaluator owns deadlines and accepted steps, never animation or Story.

var index := 0
var _origin := 0.0

func input(sample: CADInputSample) -> Dictionary:
	if not sample.pressed:
		return {}
	if sample.action != spec.pattern_steps[index] or sample.at - _origin < spec.pattern_min_seconds - 0.0000001 \
			or (index > 0 and sample.at <= _origin):
		match spec.pattern_error:
			CADInteractionSpec.PatternError.FAIL:
				return {"grade": &"miss", "progress": progress}
			CADInteractionSpec.PatternError.RESET:
				index = 0
				progress = 0.0
				_origin = sample.at
		return {}
	index += 1
	progress = float(index) / spec.pattern_steps.size()
	_origin = sample.at
	if index == spec.pattern_steps.size():
		return {"grade": &"success", "option_id": spec.option_id, "progress": 1.0}
	return {}

func tick(elapsed: float, _delta: float) -> Dictionary:
	if elapsed - _origin >= spec.pattern_deadlines[index] - 0.0000001:
		return timeout()
	return {}

func reset_input() -> void:
	# Incomplete patterns restart after pause and require fresh edges. The gate's
	# total active-time budget is unchanged, so repeated pauses add no gate time.
	index = 0
	progress = 0.0

func resume_input(elapsed: float) -> void:
	_origin = elapsed
