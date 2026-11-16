extends SkeletonModifier3D
## Procedural upper-body layer that runs after the AnimationPlayer.
##
## It adds, on top of whatever base clip is playing:
##   * breathing, listening posture, speaking micro-motion and emotion offsets
##   * short gestures from gesture_library.gd
##   * a look-at that shares yaw/pitch across spine, chest, neck and head
##
## Every rotation is expressed relative to the CURRENT animated pose, so it is
## safe over any base clip. Arm/shoulder rotations are defined in character
## space (skeleton space: +Z forward, +Y up, +X the character's left), which
## keeps them independent of the T-pose rest orientation of the kit rig.
signal gesture_finished(gesture_name: StringName)

const Gestures := preload("gesture_library.gd")
const CHAR := 0
const LOCAL := 1
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)

## kind -> [space, axis, sign_left, sign_right, [[bone_template, fraction], ...]]
## "{S}" in a bone template is replaced with Left/Right.
## Head/neck/torso: pitch = +forward (nod down), yaw = +toward character's left,
## tilt = +toward character's right.
const KINDS := {
	"head_pitch": [LOCAL, X, 1, 1, [["Head", 1.0]]],
	"head_yaw": [LOCAL, Y, 1, 1, [["Head", 1.0]]],
	"head_tilt": [LOCAL, Z, 1, 1, [["Head", 1.0]]],
	"neck_pitch": [LOCAL, X, 1, 1, [["Neck", 1.0]]],
	"neck_yaw": [LOCAL, Y, 1, 1, [["Neck", 1.0]]],
	"neck_tilt": [LOCAL, Z, 1, 1, [["Neck", 1.0]]],
	"torso_pitch": [LOCAL, X, 1, 1, [["Spine", 0.25], ["Chest", 0.35], ["UpperChest", 0.4]]],
	"torso_yaw": [LOCAL, Y, 1, 1, [["Spine", 0.25], ["Chest", 0.35], ["UpperChest", 0.4]]],
	"torso_tilt": [LOCAL, Z, 1, 1, [["Spine", 0.25], ["Chest", 0.35], ["UpperChest", 0.4]]],
	"shoulder_raise": [CHAR, Z, 1, -1, [["{S}Shoulder", 1.0]]],
	"arm_flex": [CHAR, X, -1, -1, [["{S}UpperArm", 1.0]]],
	"arm_abduct": [CHAR, Z, 1, -1, [["{S}UpperArm", 1.0]]],
	"arm_twist": [LOCAL, Y, 1, -1, [["{S}UpperArm", 1.0]]],
	"elbow": [LOCAL, X, 1, 1, [["{S}LowerArm", 1.0]]],
	"forearm_twist": [LOCAL, Y, 1, -1, [["{S}LowerArm", 1.0]]],
	"hand_flex": [LOCAL, X, 1, 1, [["{S}Hand", 1.0]]],
	"fingers_curl": [LOCAL, X, 1, 1, [
		["{S}MiddleProximal", 1.0], ["{S}MiddleIntermediate", 1.1], ["{S}MiddleDistal", 0.7],
		["{S}RingProximal", 1.0], ["{S}RingIntermediate", 1.1], ["{S}RingDistal", 0.7],
		["{S}LittleProximal", 1.0], ["{S}LittleIntermediate", 1.1], ["{S}LittleDistal", 0.7]]],
	"index_curl": [LOCAL, X, 1, 1, [
		["{S}IndexProximal", 1.0], ["{S}IndexIntermediate", 1.1], ["{S}IndexDistal", 0.7]]],
	"thumb_curl": [LOCAL, X, 1, 1, [
		["{S}ThumbMetacarpal", 0.6], ["{S}ThumbProximal", 1.0], ["{S}ThumbDistal", 0.7]]],
}

## Persistent emotion postures (degrees per kind).
const EMOTION_POSES := {
	&"neutral": {},
	&"serious": {"head_pitch": 3.0, "neck_pitch": 1.0, "torso_pitch": 1.0},
	&"expressive": {"head_pitch": -1.0, "shoulder_raise": 0.8},
	&"concerned": {"head_tilt": 6.0, "head_pitch": 2.0, "torso_pitch": 4.0, "shoulder_raise": 1.5},
	&"suspicious": {"head_pitch": 5.0, "head_tilt": -3.0, "torso_pitch": -2.0, "head_yaw": 3.0},
	&"warm": {"head_pitch": -2.0, "head_tilt": 2.0, "torso_pitch": -1.0},
}

# ---- inputs (set by NarrativeAnimator / controller) ---------------------------
var look_target: Node3D
var look_max_yaw := deg_to_rad(70.0)
var look_max_pitch := deg_to_rad(30.0)
var look_speed := 6.0
var speak_amount := 0.0       # 0..1 target
var listen_amount := 0.0      # 0..1 target
var emotion: StringName = &"neutral"
var gesture_scale := 1.0      # all gestures
var arm_scale := 1.0          # arm gestures only
var head_scale := 1.0         # speaking/listening micro-motion
var breathing_scale := 1.0
var seated := false
var enabled_arms := true
## Safety: while false only the look-at and posture layers run.
var gestures_enabled := true

# ---- state --------------------------------------------------------------------
var _idx := {}
var _head_fwd_local := Vector3(0, 0, 1)
var _look_yaw := 0.0
var _look_pitch := 0.0
var _speak_w := 0.0
var _listen_w := 0.0
var _emotion_w := {}   # kind -> smoothed degrees
var _active: Array = []
var _clock := 0.0
var _ready_bones := false

func _ready() -> void:
	_cache_bones()

func _cache_bones() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	_idx.clear()
	for i in skel.get_bone_count():
		_idx[skel.get_bone_name(i)] = i
	var head: int = _idx.get("Head", -1)
	if head >= 0:
		_head_fwd_local = skel.get_bone_global_rest(head).basis.orthonormalized().inverse() * Z
	_ready_bones = true

# ---- public api -------------------------------------------------------------------
func has_gesture(gesture_name: StringName) -> bool:
	return Gestures.has_gesture(gesture_name)

func is_gesture_active(gesture_name: StringName = &"") -> bool:
	if gesture_name == &"":
		return not _active.is_empty()
	var key := Gestures.resolve(gesture_name)
	for g in _active:
		if g.name == key:
			return true
	return false

func active_gesture_names() -> PackedStringArray:
	var out := PackedStringArray()
	for g in _active:
		out.append(String(g.name))
	return out

## Returns false if unknown, already running, or too many are running.
func play_gesture(gesture_name: StringName, side: String = "R", strength: float = 1.0) -> bool:
	var key := Gestures.resolve(gesture_name)
	if not Gestures.GESTURES.has(key) or not _ready_bones:
		return false
	var def: Dictionary = Gestures.GESTURES[key]
	if seated and not def.get("seated", false):
		return false
	if not enabled_arms and def.get("arms", false):
		return false
	if is_gesture_active(key) or _active.size() >= 3:
		return false
	_active.append({"name": key, "def": def, "t": 0.0, "side": side, "k": strength})
	return true

func clear_gestures() -> void:
	_active.clear()

func reset_state() -> void:
	_active.clear()
	var skel := get_skeleton()
	if skel != null:
		for bi in _out.keys():
			if skel.get_bone_pose_rotation(bi).is_equal_approx(_out[bi]):
				skel.set_bone_pose_rotation(bi, _base[bi])
	_base.clear()
	_out.clear()
	_look_yaw = 0.0
	_look_pitch = 0.0
	_speak_w = 0.0
	_listen_w = 0.0
	_emotion_w.clear()
	look_target = null
	speak_amount = 0.0
	listen_amount = 0.0
	emotion = &"neutral"

func gesture_duration(gesture_name: StringName) -> float:
	var key := Gestures.resolve(gesture_name)
	return float(Gestures.GESTURES[key].dur) if Gestures.GESTURES.has(key) else 0.0

func gesture_needs_free_arms(gesture_name: StringName) -> bool:
	var key := Gestures.resolve(gesture_name)
	return Gestures.GESTURES.has(key) and Gestures.GESTURES[key].get("free", false)

# ---- modifier ----------------------------------------------------------------------
func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or not _ready_bones:
		return
	var dt := clampf(get_process_delta_time(), 0.0, 0.1)
	_clock += dt
	_step(dt)

	var acc_char := {}
	var acc_local := {}
	_layer_continuous(dt, acc_char, acc_local)
	_layer_gestures(dt, acc_char, acc_local)
	_layer_look(skel, dt, acc_char, acc_local)
	_apply(skel, acc_char, acc_local)

func _step(dt: float) -> void:
	var rate := 1.0 - exp(-dt * 4.0)
	_speak_w = lerpf(_speak_w, speak_amount, rate)
	_listen_w = lerpf(_listen_w, listen_amount, rate)
	var target: Dictionary = EMOTION_POSES.get(emotion, {})
	var keys := {}
	for k in target.keys():
		keys[k] = true
	for k in _emotion_w.keys():
		keys[k] = true
	var slow := 1.0 - exp(-dt * 2.5)
	for k in keys.keys():
		var v: float = lerpf(_emotion_w.get(k, 0.0), float(target.get(k, 0.0)), slow)
		if absf(v) < 0.01 and not target.has(k):
			_emotion_w.erase(k)
		else:
			_emotion_w[k] = v

# ---- layers ---------------------------------------------------------------------------
func _noise(seed_value: float, speed: float) -> float:
	var t := _clock * speed + seed_value * 7.31
	return (sin(t) + 0.55 * sin(t * 1.73 + 1.9) + 0.3 * sin(t * 2.91 + 4.2)) / 1.85

func _add(kind: String, side: String, degrees: float, acc_char: Dictionary, acc_local: Dictionary) -> void:
	if absf(degrees) < 0.0005 or not KINDS.has(kind):
		return
	var spec: Array = KINDS[kind]
	var sided: bool = String(spec[4][0][0]).begins_with("{S}")
	var sides: Array = [""]
	if sided:
		sides = ["Left", "Right"] if side == "both" else ["Left" if side == "L" else "Right"]
	for s in sides:
		var sign_value: float = spec[2] if s == "Left" else spec[3]
		if not sided:
			sign_value = 1.0
		for part in spec[4]:
			var bone_name := String(part[0]).replace("{S}", s)
			if not _idx.has(bone_name):
				continue
			var bi: int = _idx[bone_name]
			var q := Quaternion(spec[1], deg_to_rad(degrees * float(part[1]) * sign_value))
			if spec[0] == CHAR:
				acc_char[bi] = q * acc_char.get(bi, Quaternion.IDENTITY)
			else:
				acc_local[bi] = acc_local.get(bi, Quaternion.IDENTITY) * q

func _layer_continuous(dt: float, acc_char: Dictionary, acc_local: Dictionary) -> void:
	var hs := head_scale
	# Breathing: always on, very small.
	var breath := sin(_clock * TAU * 0.23)
	_add("torso_pitch", "", 0.7 * breath * breathing_scale, acc_char, acc_local)
	_add("shoulder_raise", "both", 0.35 * breath * breathing_scale, acc_char, acc_local)
	# Listening: attentive lean, slow weight shifts, small head drift.
	if _listen_w > 0.001:
		var w := _listen_w
		_add("head_tilt", "", w * (2.6 + 1.6 * _noise(1.0, 0.45)) * hs, acc_char, acc_local)
		_add("head_pitch", "", w * (1.2 + 1.4 * _noise(2.0, 0.37)) * hs, acc_char, acc_local)
		_add("head_yaw", "", w * 1.5 * _noise(3.0, 0.31) * hs, acc_char, acc_local)
		_add("torso_pitch", "", w * (2.2 + 0.9 * _noise(4.0, 0.21)), acc_char, acc_local)
		_add("torso_tilt", "", w * 1.4 * _noise(5.0, 0.17), acc_char, acc_local)
		_add("torso_yaw", "", w * 1.2 * _noise(6.0, 0.19), acc_char, acc_local)
	# Speaking: restrained head/torso emphasis.
	if _speak_w > 0.001:
		var w2 := _speak_w
		_add("head_pitch", "", w2 * 2.2 * _noise(7.0, 1.7) * hs, acc_char, acc_local)
		_add("head_yaw", "", w2 * 2.4 * _noise(8.0, 1.1) * hs, acc_char, acc_local)
		_add("head_tilt", "", w2 * 1.6 * _noise(9.0, 0.9) * hs, acc_char, acc_local)
		_add("torso_yaw", "", w2 * 1.3 * _noise(10.0, 0.6), acc_char, acc_local)
		_add("torso_pitch", "", w2 * 0.9 * _noise(11.0, 0.8), acc_char, acc_local)
	for k in _emotion_w.keys():
		var side := "both" if String(k) in ["shoulder_raise"] else ""
		_add(String(k), side, _emotion_w[k], acc_char, acc_local)

func _layer_gestures(dt: float, acc_char: Dictionary, acc_local: Dictionary) -> void:
	if _active.is_empty():
		return
	var finished: Array = []
	for g in _active:
		g.t += dt
		var def: Dictionary = g.def
		if g.t >= float(def.dur):
			finished.append(g)
			continue
		if not gestures_enabled:
			continue
		var is_arm: bool = def.get("arms", false)
		var amp: float = gesture_scale * g.k * (arm_scale if is_arm else 1.0)
		var side: String = "both" if def.get("both", false) else String(g.side)
		for ch in def.chan:
			var kind: String = ch.k
			var deg := _sample(ch.keys, g.t) * amp
			var use_side := side
			# Arm-only kinds follow the gesture side; head/torso kinds ignore it.
			_add(kind, use_side, deg, acc_char, acc_local)
	for g in finished:
		_active.erase(g)
		gesture_finished.emit(g.name)

func _sample(keys: Array, t: float) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var t1: float = keys[i][0]
		if t <= t1:
			var t0: float = keys[i - 1][0]
			var u := (t - t0) / maxf(t1 - t0, 0.0001)
			var e := 0.5 - 0.5 * cos(PI * u)
			return lerpf(float(keys[i - 1][1]), float(keys[i][1]), e)
	return float(keys[keys.size() - 1][1])

func _layer_look(skel: Skeleton3D, dt: float, acc_char: Dictionary, acc_local: Dictionary) -> void:
	var want_yaw := 0.0
	var want_pitch := 0.0
	var valid := is_instance_valid(look_target) and look_target.is_inside_tree()
	if valid and _idx.has("Head"):
		var head_i: int = _idx["Head"]
		var head_pose := skel.get_bone_global_pose(head_i)
		var fwd := head_pose.basis.orthonormalized() * _head_fwd_local
		var eye := head_pose.origin + head_pose.basis.orthonormalized() * Vector3(0, 0.1, 0.0)
		var tgt := skel.to_local(look_target.global_position)
		var dir := tgt - eye
		if dir.length() > 0.05:
			var cur_yaw := atan2(fwd.x, fwd.z)
			var cur_pitch := atan2(fwd.y, Vector2(fwd.x, fwd.z).length())
			var want_y := atan2(dir.x, dir.z)
			var want_p := atan2(dir.y, Vector2(dir.x, dir.z).length())
			want_yaw = clampf(wrapf(want_y - cur_yaw, -PI, PI), -look_max_yaw, look_max_yaw)
			want_pitch = clampf(want_p - cur_pitch, -look_max_pitch, look_max_pitch)
	var rate := 1.0 - exp(-dt * look_speed)
	_look_yaw = lerpf(_look_yaw, want_yaw, rate)
	_look_pitch = lerpf(_look_pitch, want_pitch, rate)
	if absf(_look_yaw) < 0.0005 and absf(_look_pitch) < 0.0005:
		return
	# Share the rotation down the chain. Pitch axis follows the accumulated yaw.
	var yaw_parts := [["Spine", 0.08], ["Chest", 0.12], ["UpperChest", 0.15], ["Neck", 0.25], ["Head", 0.40]]
	var pitch_parts := {"UpperChest": 0.1, "Neck": 0.3, "Head": 0.6}
	var cum := 0.0
	for part in yaw_parts:
		var bone_name: String = part[0]
		if not _idx.has(bone_name):
			continue
		var bi: int = _idx[bone_name]
		cum += _look_yaw * float(part[1])
		var q := Quaternion(Y, _look_yaw * float(part[1]))
		if pitch_parts.has(bone_name):
			var axis := Quaternion(Y, cum) * X
			q = Quaternion(axis, -_look_pitch * float(pitch_parts[bone_name])) * q
		acc_char[bi] = q * acc_char.get(bi, Quaternion.IDENTITY)

# ---- apply ---------------------------------------------------------------------------
## Idempotent: if the AnimationPlayer did not refresh a bone this frame (its pose still equals
## what we wrote last frame) we start again from the remembered base pose instead of stacking
## the offset a second time. Bones we stop touching are restored.
var _base := {}   # bone -> rotation before our offset
var _out := {}    # bone -> rotation we wrote

func _apply(skel: Skeleton3D, acc_char: Dictionary, acc_local: Dictionary) -> void:
	var touched := {}
	for k in acc_char.keys():
		touched[k] = true
	for k in acc_local.keys():
		touched[k] = true
	# Restore bones that were modified last frame but are not modified now.
	for bi in _out.keys():
		if not touched.has(bi):
			if skel.get_bone_pose_rotation(bi).is_equal_approx(_out[bi]):
				skel.set_bone_pose_rotation(bi, _base[bi])
			_out.erase(bi)
			_base.erase(bi)
	var order: Array = touched.keys()
	order.sort()  # parents have lower indices than children in this rig
	for bi in order:
		var parent := skel.get_bone_parent(bi)
		var gp := Quaternion.IDENTITY
		if parent >= 0:
			gp = skel.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
		var base := skel.get_bone_pose_rotation(bi)
		if _out.has(bi) and base.is_equal_approx(_out[bi]):
			base = _base[bi]
		var qc: Quaternion = acc_char.get(bi, Quaternion.IDENTITY)
		var ql: Quaternion = acc_local.get(bi, Quaternion.IDENTITY)
		var result := (gp.inverse() * qc * gp * base * ql).normalized()
		_base[bi] = base
		_out[bi] = result
		skel.set_bone_pose_rotation(bi, result)
