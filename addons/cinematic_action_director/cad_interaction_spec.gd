class_name CADInteractionSpec
extends Resource
## Optional CADGate extension. Missing interaction keeps the legacy evaluator.
## Routes override named grade destinations in the existing CADSequence graph.

enum Family { GESTURE, CHOICE, TIMING, PASSIVE }
enum Gesture { PRESS, HOLD, TIMED_RELEASE, CHORD }
enum WrongInput { IGNORE, FAIL }

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

func validation_errors(options: Array[CADOption], window: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("Interaction needs a stable id.")
	if not is_finite(window) or window <= 0.0:
		errors.append("Interaction window must be finite and positive.")
	if family not in [Family.GESTURE, Family.CHOICE, Family.TIMING, Family.PASSIVE]:
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
	if family in [Family.GESTURE, Family.TIMING, Family.PASSIVE]:
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
	for action in actions + monitored_actions:
		if action not in found:
			found.append(action)
	for option in options:
		if option != null and option.action not in found:
			found.append(option.action)
	return found
