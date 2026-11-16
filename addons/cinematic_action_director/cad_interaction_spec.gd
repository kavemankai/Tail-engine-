class_name CADInteractionSpec
extends Resource
## Optional CADGate extension. Missing interaction keeps the legacy evaluator.
## Routes override named grade destinations in the existing CADSequence graph.

enum Family { GESTURE, CHOICE }
enum Gesture { PRESS, HOLD }
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
## -1 acquires the first controller to send a matching press.
@export var controller_device := -1
@export var routes: Dictionary[StringName, StringName] = {}

func validation_errors(options: Array[CADOption], window: float) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("Interaction needs a stable id.")
	if not is_finite(window) or window <= 0.0:
		errors.append("Interaction window must be finite and positive.")
	if family not in [Family.GESTURE, Family.CHOICE]:
		errors.append("Unsupported interaction family.")
	if controller_device < -1 or wrong_input not in [WrongInput.IGNORE, WrongInput.FAIL]:
		errors.append("Invalid interaction input policy.")
	if family == Family.GESTURE:
		if gesture not in [Gesture.PRESS, Gesture.HOLD] or actions.size() != 1:
			errors.append("Gesture needs one action and a supported mode.")
		if gesture == Gesture.HOLD and (not is_finite(hold_seconds) or hold_seconds <= 0.0 or hold_seconds > window):
			errors.append("Hold must fit inside the interaction window.")
		if not options.any(func(option: CADOption) -> bool: return option != null and option.id == option_id):
			errors.append("Interaction references a missing option '%s'." % option_id)
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
