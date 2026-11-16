class_name ConversationAnimationController
extends Node
## Shared, narrative-independent animation controller for Humanoid Kit characters.
##
## One instance lives under each NarrativeCharacter. External systems (a dialogue
## manager, a cutscene, a test UI) call the methods below and never touch bones,
## tracks or the AnimationPlayer. No dialogue text or story logic lives here.
##
## State model
##   conversation_mode  false = ordinary locomotion/idle, true = conversational posture
##   speaking / listening  mutually exclusive; setting one clears the other
##   emotion  persistent posture (neutral, serious, expressive, concerned, suspicious, warm)
##            or a one-shot reaction (surprised, dismissive, agreeing, disagreeing, thinking)
##   seated   sitting posture (separate from conversation mode)
## Every call is idempotent and safe in any order.

signal conversation_mode_changed(enabled: bool)
signal speaking_changed(enabled: bool)
signal listening_changed(enabled: bool)
signal emotion_changed(emotion: StringName)
signal gesture_started(gesture: StringName)
signal gesture_finished(gesture: StringName)
signal seated_changed(seated: bool)
signal look_target_changed(target: Node3D)
signal reset_to_idle_done

const Gestures := preload("gesture_library.gd")

const EMOTIONS: Array[StringName] = [&"neutral", &"serious", &"expressive", &"concerned", &"suspicious", &"warm"]
## One-shot reactions: emotion name -> gesture. The persistent emotion is left untouched.
const REACTIONS := {
	&"surprised": &"surprise", &"surprise": &"surprise",
	&"dismissive": &"dismiss", &"dismiss": &"dismiss",
	&"agreeing": &"nod", &"agree": &"nod", &"agreement": &"nod",
	&"disagreeing": &"shake", &"disagree": &"shake", &"disagreement": &"shake",
	&"thinking": &"think", &"hesitant": &"think", &"hesitation": &"think",
}
const EMOTION_ALIASES := {
	&"concern": &"concerned", &"worried": &"concerned", &"suspicion": &"suspicious",
	&"wary": &"suspicious", &"happy": &"warm", &"friendly": &"warm", &"calm": &"neutral",
	&"restrained": &"serious", &"stern": &"serious", &"animated": &"expressive",
}

## Automatic gestures while speaking/listening. 0 = none, 1 = frequent.
@export_range(0.0, 1.0) var gesture_frequency := 0.5
@export var auto_gestures := true
## Turn the whole body toward a look target when the head alone cannot reach it.
@export var body_follows_look := true

var body: CharacterBody3D
var animator: Node
var profile: Resource

var conversation_mode := false
var speaking := false
var listening := false
var emotion: StringName = &"neutral"
var seated := false
var look_target: Node3D

var _gesture_timer := 3.0
var _body_turning := false
var _owned_look_point: Node3D
var _eye_focus: Node3D
var _rng := RandomNumberGenerator.new()

# ---- wiring --------------------------------------------------------------------------
## Called by NarrativeCharacter once its animator has built the model.
func setup(character_body: CharacterBody3D, character_animator: Node) -> void:
	body = character_body
	animator = character_animator
	profile = animator.profile
	_rng.randomize()
	if animator.modifier != null and not animator.gesture_finished.is_connected(_on_gesture_finished):
		animator.gesture_finished.connect(_on_gesture_finished)

func is_ready() -> bool:
	return body != null and animator != null and is_instance_valid(animator.modifier)

# ---- required interface ----------------------------------------------------------------
func set_conversation_mode(enabled: bool) -> void:
	if enabled == conversation_mode:
		return
	conversation_mode = enabled
	if not enabled:
		_clear_conversation_state()
	_push_state()
	conversation_mode_changed.emit(enabled)

func set_speaking(enabled: bool) -> void:
	if enabled and not conversation_mode:
		set_conversation_mode(true)
	if enabled == speaking:
		return
	speaking = enabled
	if enabled and listening:
		listening = false
		listening_changed.emit(false)
	_gesture_timer = _rng.randf_range(0.8, 1.8)
	_push_state()
	speaking_changed.emit(enabled)

func set_listening(enabled: bool) -> void:
	if enabled and not conversation_mode:
		set_conversation_mode(true)
	if enabled == listening:
		return
	listening = enabled
	if enabled and speaking:
		speaking = false
		speaking_changed.emit(false)
	_gesture_timer = _rng.randf_range(2.0, 4.0)
	_push_state()
	listening_changed.emit(enabled)

## Persistent emotions change posture; reaction names play a one-shot gesture.
func set_emotion(emotion_name: StringName) -> void:
	var key: StringName = EMOTION_ALIASES.get(emotion_name, emotion_name)
	if REACTIONS.has(key):
		play_gesture(REACTIONS[key])
		return
	if not EMOTIONS.has(key):
		push_warning("ConversationAnimationController: unknown emotion '%s'" % emotion_name)
		return
	if key == emotion:
		return
	emotion = key
	_push_state()
	emotion_changed.emit(key)

## Returns true if the gesture started. False for unknown, blocked or already-running gestures.
func play_gesture(gesture_name: StringName, side: String = "R") -> bool:
	if not is_ready():
		return false
	var key := Gestures.resolve(gesture_name)
	if not Gestures.GESTURES.has(key):
		push_warning("ConversationAnimationController: unknown gesture '%s'" % gesture_name)
		return false
	if not _gesture_allowed(key):
		return false
	var def: Dictionary = Gestures.GESTURES[key]
	# Arm gestures would fight the walk cycle and jump poses.
	if def.get("arms", false) and (_speed() > 0.3 or not body.is_on_floor()):
		return false
	if def.get("free", false) and not seated:
		animator.request_free_arms(float(def.dur) + 0.6)
	if not animator.modifier.play_gesture(key, side):
		return false
	gesture_started.emit(key)
	return true

func set_look_target(target: Node3D) -> void:
	if target == look_target:
		return
	_disconnect_target()
	if target == null:
		clear_look_target()
		return
	look_target = target
	if not target.tree_exiting.is_connected(clear_look_target):
		target.tree_exiting.connect(clear_look_target)
	if is_ready():
		animator.modifier.look_target = target
	look_target_changed.emit(target)

func clear_look_target() -> void:
	_disconnect_target()
	look_target = null
	if is_instance_valid(animator) and is_instance_valid(animator.modifier):
		animator.modifier.look_target = null
	if _body_turning and is_instance_valid(body):
		body.clear_look_target()
	_body_turning = false
	look_target_changed.emit(null)

func set_seated(enabled: bool) -> void:
	if enabled == seated or not is_instance_valid(body):
		return
	seated = enabled
	body.set_combat_state(&"sit" if enabled else &"neutral")
	_push_state()
	seated_changed.emit(enabled)

## Clear conversation state and any running gestures. Seated posture is kept unless stand_up.
func reset_to_idle(stand_up: bool = false) -> void:
	_clear_conversation_state()
	conversation_mode = false
	if stand_up and seated:
		set_seated(false)
	if is_ready():
		animator.reset_conversation()
	_push_state()
	reset_to_idle_done.emit()

# ---- extras ---------------------------------------------------------------------------
func set_gesture_frequency(value: float) -> void:
	gesture_frequency = clampf(value, 0.0, 1.0)

func look_at_point(world_position: Vector3) -> void:
	if not is_instance_valid(_owned_look_point):
		_owned_look_point = Node3D.new()
		_owned_look_point.name = "LookPoint"
		add_child(_owned_look_point)
	_owned_look_point.global_position = world_position
	set_look_target(_owned_look_point)

func list_gestures() -> PackedStringArray:
	return Gestures.names()

func list_emotions() -> PackedStringArray:
	var out := PackedStringArray()
	for e in EMOTIONS:
		out.append(String(e))
	for k in REACTIONS.keys():
		if not out.has(String(k)):
			out.append(String(k))
	return out

func has_gesture(gesture_name: StringName) -> bool:
	return Gestures.has_gesture(gesture_name)

func get_state() -> Dictionary:
	return {
		"conversation_mode": conversation_mode, "speaking": speaking, "listening": listening,
		"emotion": emotion, "seated": seated,
		"look_target": look_target.name if is_instance_valid(look_target) else &"",
		"base_clip": animator.current_base_clip() if animator else &"",
		"active_gestures": animator.modifier.active_gesture_names() if is_ready() else PackedStringArray(),
	}

## Head anchor / eye focus markers live in the model scene; a fallback is created if absent.
func get_eye_focus() -> Node3D:
	if is_instance_valid(_eye_focus):
		return _eye_focus
	var model: Node = animator.model if animator else null
	if model != null:
		_eye_focus = model.get_node_or_null("%EyeFocus") as Node3D
		if _eye_focus == null:
			_eye_focus = model.find_child("EyeFocus", true, false) as Node3D
	if _eye_focus == null and model != null and is_instance_valid(animator.skeleton):
		var att := BoneAttachment3D.new()
		att.name = "HeadAttachmentFallback"
		att.bone_name = "Head"
		animator.skeleton.add_child(att)
		var mk := Marker3D.new()
		mk.name = "EyeFocus"
		mk.position = Vector3(0, 0.1, 0.08)
		att.add_child(mk)
		_eye_focus = mk
	return _eye_focus

# ---- internals ------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not is_ready():
		return
	_update_body_turn()
	if not (conversation_mode and auto_gestures and gesture_frequency > 0.0):
		return
	if not (speaking or listening):
		return
	_gesture_timer -= delta
	if _gesture_timer > 0.0:
		return
	_fire_auto_gesture()
	var f := gesture_frequency
	var base := lerpf(10.0, 3.0, f) if speaking else lerpf(15.0, 6.0, f)
	_gesture_timer = base * _rng.randf_range(0.7, 1.4)

func _fire_auto_gesture() -> void:
	if animator.modifier.is_gesture_active() or not animator.action.is_empty() or animator.is_turning():
		return
	var pool: PackedStringArray
	if speaking:
		pool = profile.seated_speaking_gestures if seated else profile.speaking_gestures
	else:
		pool = profile.listening_gestures
	var candidates: Array[StringName] = []
	for g in pool:
		var key := Gestures.resolve(StringName(g))
		if not Gestures.GESTURES.has(key) or not _gesture_allowed(key):
			continue
		if Gestures.GESTURES[key].get("arms", false) and speaking and not profile.arm_beats_while_speaking:
			continue
		candidates.append(key)
	if candidates.is_empty():
		return
	var pick: StringName = candidates[_rng.randi() % candidates.size()]
	var side := "R" if _rng.randf() < 0.65 else "L"
	play_gesture(pick, side)

func _gesture_allowed(key: StringName) -> bool:
	var allowed: PackedStringArray = profile.allowed_gestures
	if allowed.is_empty():
		return true
	for a in allowed:
		if Gestures.resolve(StringName(a)) == key:
			return true
	return false

func _update_body_turn() -> void:
	if not body_follows_look or not conversation_mode or not is_instance_valid(look_target) or not is_instance_valid(body):
		if _body_turning and is_instance_valid(body):
			body.clear_look_target()
			_body_turning = false
		return
	if seated or body.dead:
		return
	var local := body.to_local(look_target.global_position)
	var err := absf(atan2(local.x, local.z))
	if not _body_turning and err > deg_to_rad(profile.body_turn_threshold_deg):
		_body_turning = true
	elif _body_turning and err < deg_to_rad(6.0):
		_body_turning = false
		body.clear_look_target()
	if _body_turning:
		body.rotation_speed = profile.body_turn_speed
		body.set_look_target(look_target.global_position)

func _speed() -> float:
	return Vector2(body.velocity.x, body.velocity.z).length() if is_instance_valid(body) else 0.0

func _clear_conversation_state() -> void:
	if speaking:
		speaking = false
		speaking_changed.emit(false)
	if listening:
		listening = false
		listening_changed.emit(false)
	if emotion != &"neutral":
		emotion = &"neutral"
		emotion_changed.emit(&"neutral")
	if is_ready():
		animator.modifier.clear_gestures()
	clear_look_target()

func _push_state() -> void:
	if not is_instance_valid(animator):
		return
	animator.conversation = conversation_mode
	animator.speaking = speaking
	animator.listening = listening
	animator.emotion = emotion
	if is_instance_valid(animator.modifier):
		animator.modifier.seated = seated

func _disconnect_target() -> void:
	if is_instance_valid(look_target) and look_target.tree_exiting.is_connected(clear_look_target):
		look_target.tree_exiting.disconnect(clear_look_target)

func _on_gesture_finished(gesture_name: StringName) -> void:
	gesture_finished.emit(gesture_name)
