class_name AutoPlayer
extends Node
## Plays an episode from a policy, for tests and recordings.

## [#opt=...] names to pick whenever one is offered. Otherwise the choice is
## left alone, so a timed one runs out.
var options: Array = []
## Beat id -> action to press, or "hold:action". Beats not listed are missed.
var gates: Dictionary = {}
## Hotspot names to walk to and use, in order.
var hotspots: Array = []
## Seconds to wait before each input, so recordings show the prompt.
var delay := 0.0
## Step ids in the order they started.
var steps: Array[StringName] = []
## Dialogue lines shown, as "speaker: text".
var lines: Array[String] = []

var _target: Node3D
## Stuck recovery: the walker steers straight at its target, so scenery in the
## way would hold it forever. After a stall it sidesteps for a moment.
const STALL_FRAMES := 20
const SIDESTEP_FRAMES := 40
var _last_position := Vector3.INF
var _stalled := 0
var _sidestep := 0
var _sidestep_sign := 1.0

func _ready() -> void:
	Flow.step_started.connect(func(step: TEStep) -> void: steps.append(step.id))
	Flow.balloon_opened.connect(_on_balloon)
	Flow.director_started.connect(_on_director)
	Flow.hub_entered.connect(_on_hub)

func _exit_tree() -> void:
	_steer(Vector3.ZERO)

func _on_balloon(balloon: TEBalloon) -> void:
	balloon.line_shown.connect(func(line: DialogueLine) -> void: lines.append("%s: %s" % [line.character, line.text]))
	balloon.choices_shown.connect(func(_line: DialogueLine, _responses: Array) -> void:
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		for option: String in options:
			if is_instance_valid(balloon) and balloon.pick_option(option):
				return)

func _on_director(director: CADDirector) -> void:
	director.gate_opened.connect(func(beat: CADBeat, _options: Array[CADOption], _window: float) -> void:
		var action: String = gates.get(beat.id, "")
		if action == "":
			return
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if not is_instance_valid(director) or not director.active():
			return
		if action.begins_with("hold:"):
			_send(action.trim_prefix("hold:"), true)
			await director.gate_resolved
			_send(action.trim_prefix("hold:"), false)
		else:
			_send(action, true)
			_send(action, false))

func _on_hub(hub: TEHub) -> void:
	for hotspot_name: String in hotspots:
		var target := hub.get_node_or_null(hotspot_name) as TEHotspot
		if target == null or not hub.available(target):
			continue
		_target = target
		while hub.is_processing() and _distance() > target.radius * 0.7:
			await get_tree().physics_frame
		_target = null
		_steer(Vector3.ZERO)
		if not hub.is_processing():
			return
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
		await hub.use(target)
		if not hub.is_processing():
			return

func _physics_process(_delta: float) -> void:
	if is_instance_valid(_target) and Flow.actors.has(Flow.episode.player):
		var to := _target.global_position - Flow.actors[Flow.episode.player].global_position
		to.y = 0.0
		var heading := to.normalized()
		var here: Vector3 = Flow.actors[Flow.episode.player].global_position
		_stalled = _stalled + 1 if here.distance_to(_last_position) < 0.01 else 0
		_last_position = here
		if _stalled >= STALL_FRAMES and _sidestep <= 0:
			_sidestep = SIDESTEP_FRAMES
			_sidestep_sign = -_sidestep_sign
			_stalled = 0
		if _sidestep > 0:
			_sidestep -= 1
			heading = (heading + Vector3(-heading.z, 0.0, heading.x) * _sidestep_sign * 2.0).normalized()
		_steer(heading)

func _distance() -> float:
	var to := _target.global_position - Flow.actors[Flow.episode.player].global_position
	to.y = 0.0
	return to.length()

func _steer(direction: Vector3) -> void:
	var strengths := {&"move_right": direction.x, &"move_left": -direction.x, &"move_back": direction.z, &"move_forward": -direction.z}
	for action: StringName in strengths:
		if strengths[action] > 0.05:
			Input.action_press(action, strengths[action])
		else:
			Input.action_release(action)

func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
