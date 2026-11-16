class_name CADInteractionSpec
extends Resource
## Optional CADGate extension. Missing interaction keeps the legacy evaluator.
## Routes override named grade destinations in the existing CADSequence graph.

enum Family { GESTURE, CHOICE, TIMING, PASSIVE, DIRECTION, PATTERN, TARGET }
enum Gesture { PRESS, HOLD, TIMED_RELEASE, CHORD }
enum WrongInput { IGNORE, FAIL }
enum PatternError { IGNORE, RESET, FAIL }
enum DirectionMode { FLICK, HOLD, SELECT }
enum DirectionSpace { INPUT, CAMERA }
enum Sector { UP, UP_RIGHT, RIGHT, DOWN_RIGHT, DOWN, DOWN_LEFT, LEFT, UP_LEFT }

@export var id: StringName
@export var family: Family = Family.GESTURE
@export var gesture: Gesture = Gesture.PRESS
@export var option_id: StringName
@export var actions: Array[StringName] = []
## Extra mapped actions whose presses use wrong_input (other keys are ignored).
@export var monitored_actions: Array[StringName] = []
@export var wrong_input: WrongInput = WrongInput.IGNORE
@export_range(0.01, 60.0) var hold_seconds := 0.5
@export_range(0.01, 1.0) var chord_seconds := 0.08
## Relative to gate opening, or timing_marker once received.
@export_range(0.0, 60.0) var ideal_seconds := 0.5
@export var timing_marker: StringName
@export_range(0.0, 2.0) var perfect_seconds := 0.06
@export_range(0.0, 2.0) var success_seconds := 0.16
@export_range(0.0, 2.0) var partial_seconds := 0.3
## Passive actions are an explicit forbidden-input set, not an ordinary timeout.
@export_range(0.01, 60.0) var passive_seconds := 1.0
## -1 acquires the first controller to send a matching press.
@export var controller_device := -1
@export var routes: Dictionary[StringName, StringName] = {}
## Ordered left/right/up/down logical actions, each freely remappable.
@export var direction_actions: Array[StringName] = [&"cad_dir_left", &"cad_dir_right", &"cad_dir_up", &"cad_dir_down"]
@export var direction_mode: DirectionMode = DirectionMode.FLICK
@export var direction_space: DirectionSpace = DirectionSpace.INPUT
@export var direction_sector: Sector = Sector.LEFT
@export var direction_eight_way := false
@export_range(0.01, 1.0) var direction_activation := 0.65
@export_range(0.0, 0.99) var direction_rearm := 0.25
## Coalesce independently delivered axis/key events before deciding a sector.
@export_range(0.0, 0.2) var direction_settle_seconds := 0.025
## SELECT maps sectors to existing gate option IDs (not display labels).
@export var direction_options: Dictionary[int, StringName] = {}

## Repeated actions belong here, not in actions. Alternation is ordinary data.
@export var pattern_steps: Array[StringName] = []
## Duration from opening/previous accepted step. Timeout wins exact ties.
@export var pattern_deadlines: Array[float] = []
## Minimum interval for every step, including the first. Early edges use policy.
@export_range(0.0, 5.0) var pattern_min_seconds := 0.0
@export var pattern_error: PatternError = PatternError.IGNORE

## Target IDs bind to the stage registry; values are existing gate option IDs.
@export var target_options: Dictionary[StringName, StringName] = {}
@export var target_confirm_action := &"cad_a"
@export var target_next_action := &"cad_b"
@export var target_previous_action := &"cad_dodge"
## Zero is immediate selection; positive values require continuous held lock.
@export_range(0.0, 10.0) var target_lock_seconds := 0.0
## Coordinates/radius are viewport-height units, independent of aspect ratio.
@export_range(0.01, 0.5) var target_radius := 0.08
@export_range(0.01, 4.0) var target_cursor_speed := 0.6

func validation_errors(options: Array[CADOption], window: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("Interaction needs a stable id.")
	if not is_finite(window) or window <= 0.0:
		errors.append("Interaction window must be finite and positive.")
	if family not in [Family.GESTURE, Family.CHOICE, Family.TIMING, Family.PASSIVE, Family.DIRECTION, Family.PATTERN, Family.TARGET]:
		errors.append("Unsupported interaction family.")
	if controller_device < -1 or wrong_input not in [WrongInput.IGNORE, WrongInput.FAIL]:
		errors.append("Invalid interaction input policy.")
	if family == Family.GESTURE:
		if gesture not in [Gesture.PRESS, Gesture.HOLD, Gesture.TIMED_RELEASE, Gesture.CHORD]:
			errors.append("Unsupported gesture mode.")
		if gesture != Gesture.CHORD and actions.size() != 1:
			errors.append("Gesture needs one action.")
		if gesture == Gesture.CHORD and (actions.size() < 2 or actions.size() > 4 or not is_finite(chord_seconds) \
				or chord_seconds <= 0.0 or chord_seconds >= window):
			errors.append("Chord needs 2–4 unique actions and a tolerance inside the window.")
		if gesture == Gesture.HOLD and (not is_finite(hold_seconds) or hold_seconds <= 0.0 or hold_seconds >= window):
			errors.append("Hold must fit inside the interaction window.")
	if uses_fixed_option():
		if not options.any(func(option: CADOption) -> bool: return option != null and option.id == option_id):
			errors.append("Interaction references a missing option '%s'." % option_id)
	if family == Family.TIMING and actions.size() != 1:
		errors.append("Timing needs one action.")
	if family == Family.TIMING or (family == Family.GESTURE and gesture == Gesture.TIMED_RELEASE):
		if timing_marker == &"done":
			errors.append("The reserved done marker cannot anchor an interaction.")
		if not is_finite(ideal_seconds) or ideal_seconds < 0.0 or ideal_seconds >= window \
				or not is_finite(perfect_seconds) or not is_finite(success_seconds) or not is_finite(partial_seconds) \
				or perfect_seconds < 0.0 or success_seconds < perfect_seconds or partial_seconds < success_seconds:
			errors.append("Timing needs finite ordered grade tolerances and an ideal inside the window.")
	if family == Family.PASSIVE and (actions.is_empty() or not is_finite(passive_seconds) \
			or passive_seconds <= 0.0 or passive_seconds > window):
		errors.append("Passive needs forbidden actions and a completion time inside the window.")
	if family in [Family.DIRECTION, Family.TARGET]:
		if direction_actions.size() != 4 or _has_duplicates(direction_actions) or not actions.is_empty():
			errors.append("Direction needs four unique direction_actions (left/right/up/down); use monitored_actions for other controls.")
		if direction_mode not in [DirectionMode.FLICK, DirectionMode.HOLD, DirectionMode.SELECT] \
				or direction_space not in [DirectionSpace.INPUT, DirectionSpace.CAMERA]:
			errors.append("Invalid direction mode or coordinate space.")
		if not is_finite(direction_activation) or not is_finite(direction_rearm) \
				or direction_activation <= 0.0 or direction_activation > 1.0 or direction_rearm < 0.0 or direction_rearm >= direction_activation:
			errors.append("Direction needs 0 <= rearm < activation <= 1.")
		if direction_mode == DirectionMode.HOLD and (not is_finite(hold_seconds) or hold_seconds <= 0.0 or hold_seconds >= window):
			errors.append("Directional hold must fit inside the interaction window.")
		if not is_finite(direction_settle_seconds) or direction_settle_seconds < 0.0 or direction_settle_seconds >= window \
				or (direction_mode == DirectionMode.HOLD and hold_seconds + direction_settle_seconds >= window):
			errors.append("Direction settling and hold duration must fit inside the window.")
		if direction_mode == DirectionMode.SELECT:
			if direction_options.is_empty():
				errors.append("Directional selection needs sector-to-option mappings.")
			for sector in direction_options:
				if not valid_sector(sector) or not options.any(func(option: CADOption) -> bool: return option != null and option.id == direction_options[sector]):
					errors.append("Invalid direction selection sector/option: %s." % sector)
		elif not valid_sector(direction_sector):
			errors.append("Direction sector must be enabled by the four/eight-way policy.")
	if family == Family.TARGET:
		var controls: Array[StringName] = [target_confirm_action, target_next_action, target_previous_action]
		if _has_duplicates(controls) or controls.any(func(action: StringName) -> bool: return action in direction_actions):
			errors.append("Target confirm/next/previous actions must be distinct and separate from aim directions.")
		if target_options.is_empty():
			errors.append("Target needs target-to-option mappings.")
		for target_id in target_options:
			if target_id == &"" or not options.any(func(option: CADOption) -> bool: return option != null and option.id == target_options[target_id]):
				errors.append("Invalid target ID/option mapping: %s." % target_id)
		if not is_finite(target_lock_seconds) or target_lock_seconds < 0.0 or target_lock_seconds >= window \
				or not is_finite(target_radius) or target_radius <= 0.0 or target_radius > 0.5 \
				or not is_finite(target_cursor_speed) or target_cursor_speed <= 0.0 or target_cursor_speed > 4.0:
			errors.append("Target needs finite lock duration inside window, radius in (0, 0.5], and cursor speed in (0, 4].")
	if family == Family.PATTERN:
		if pattern_steps.is_empty() or pattern_steps.size() > 64 or not actions.is_empty():
			errors.append("Pattern needs 1–64 steps and empty actions; repetitions go in pattern_steps.")
		if pattern_deadlines.size() != pattern_steps.size():
			errors.append("Pattern needs one relative deadline per step.")
		if not is_finite(pattern_min_seconds) or pattern_min_seconds < 0.0 \
				or pattern_error not in [PatternError.IGNORE, PatternError.RESET, PatternError.FAIL]:
			errors.append("Invalid Pattern minimum interval or error policy.")
		for deadline in pattern_deadlines:
			if not is_finite(deadline) or deadline <= pattern_min_seconds or deadline > window:
				errors.append("Pattern deadlines must exceed the minimum interval and fit in the gate window.")
		if pattern_min_seconds * pattern_steps.size() >= window:
			errors.append("Pattern minimum intervals cannot fit in the gate window.")
	var unique: Dictionary = {}
	for action in actions:
		if unique.has(action):
			errors.append("Duplicate interaction action: %s" % action)
		unique[action] = true
	if family == Family.CHOICE and options.is_empty():
		errors.append("Choice interaction needs options.")
	for action in input_actions(options):
		if action == &"" or not InputMap.has_action(action):
			errors.append("Missing interaction InputMap action: %s" % action)
	for grade in routes:
		if grade not in CADResult.GRADES or grade == &"cancelled" or routes[grade] == &"":
			errors.append("Invalid interaction grade route: %s" % grade)
	return errors

func input_actions(options: Array[CADOption]) -> Array[StringName]:
	var found: Array[StringName] = []
	for action in actions + monitored_actions + (pattern_steps if family == Family.PATTERN else []):
		if action not in found:
			found.append(action)
	if family == Family.TARGET:
		for action in [target_confirm_action, target_next_action, target_previous_action]:
			if action not in found:
				found.append(action)
	if family in [Family.DIRECTION, Family.TARGET]:
		for action in direction_actions:
			if action not in found:
				found.append(action)
	for option in options:
		if option != null and option.action not in found:
			found.append(option.action)
	return found

func uses_fixed_option() -> bool:
	return family not in [Family.CHOICE, Family.TARGET] and not (family == Family.DIRECTION and direction_mode == DirectionMode.SELECT)

func valid_sector(value: int) -> bool:
	return value >= 0 and value < 8 and (direction_eight_way or value % 2 == 0)

func _has_duplicates(values: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false
