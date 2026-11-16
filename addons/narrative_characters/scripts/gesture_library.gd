extends RefCounted
## Procedural gesture definitions for the conversation pose layer.
##
## Angles are in degrees. Keys are [time_seconds, degrees] pairs, eased with a
## cosine curve between keys, so every gesture starts and ends at zero offset.
## Channel kinds are defined in conversation_pose_modifier.gd (KINDS).
##
## Per-gesture flags:
##   dur    total length in seconds
##   seated true if safe to play while seated
##   arms   true if the gesture moves the arms (profiles can scale or disable)
##   free   true if arms must not be folded (folded-arm idles switch to a free idle)
##   both   true if both arms/sides move; otherwise `side` ("R" default) is used
##   chan   list of {k: kind, keys: [...]}

const GESTURES := {
	# ---- head and torso only -------------------------------------------------
	&"nod": {"dur": 0.95, "seated": true, "arms": false, "chan": [
		{"k": "head_pitch", "keys": [[0, 0], [0.16, 9], [0.34, -0.5], [0.54, 7], [0.78, 0], [0.95, 0]]},
		{"k": "neck_pitch", "keys": [[0, 0], [0.16, 2.5], [0.34, 0], [0.54, 2], [0.95, 0]]},
		{"k": "torso_pitch", "keys": [[0, 0], [0.2, 1.5], [0.6, 1], [0.95, 0]]}]},
	&"nod_small": {"dur": 0.6, "seated": true, "arms": false, "chan": [
		{"k": "head_pitch", "keys": [[0, 0], [0.15, 6], [0.36, -0.5], [0.6, 0]]},
		{"k": "neck_pitch", "keys": [[0, 0], [0.15, 1.5], [0.6, 0]]}]},
	&"shake": {"dur": 1.1, "seated": true, "arms": false, "chan": [
		{"k": "head_yaw", "keys": [[0, 0], [0.14, 14], [0.38, -13], [0.62, 10], [0.84, -6], [1.1, 0]]},
		{"k": "neck_yaw", "keys": [[0, 0], [0.14, 4], [0.38, -4], [0.62, 3], [1.1, 0]]},
		{"k": "head_tilt", "keys": [[0, 0], [0.38, 2], [0.8, -1], [1.1, 0]]}]},
	&"shake_small": {"dur": 0.7, "seated": true, "arms": false, "chan": [
		{"k": "head_yaw", "keys": [[0, 0], [0.13, 8], [0.34, -7], [0.54, 3], [0.7, 0]]}]},
	&"tilt": {"dur": 1.7, "seated": true, "arms": false, "chan": [
		{"k": "head_tilt", "keys": [[0, 0], [0.4, 9], [1.2, 9], [1.7, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.4, 2], [1.2, 2], [1.7, 0]]},
		{"k": "torso_pitch", "keys": [[0, 0], [0.5, 2.5], [1.2, 2.5], [1.7, 0]]}]},
	&"lean_in": {"dur": 2.2, "seated": true, "arms": false, "chan": [
		{"k": "torso_pitch", "keys": [[0, 0], [0.6, 6], [1.6, 6], [2.2, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.6, -3], [1.6, -3], [2.2, 0]]}]},
	&"glance_away": {"dur": 1.6, "seated": true, "arms": false, "chan": [
		{"k": "head_yaw", "keys": [[0, 0], [0.3, -16], [1.1, -16], [1.6, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.3, 4], [1.1, 4], [1.6, 0]]},
		{"k": "neck_yaw", "keys": [[0, 0], [0.3, -5], [1.1, -5], [1.6, 0]]}]},
	# ---- reactions -------------------------------------------------------------
	&"surprise": {"dur": 1.5, "seated": true, "arms": true, "both": true, "chan": [
		{"k": "torso_pitch", "keys": [[0, 0], [0.14, -6], [0.9, -4], [1.5, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.14, -7], [0.9, -4], [1.5, 0]]},
		{"k": "shoulder_raise", "keys": [[0, 0], [0.14, 7], [0.9, 4], [1.5, 0]]},
		{"k": "arm_flex", "keys": [[0, 0], [0.14, 12], [0.9, 8], [1.5, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.14, 7], [0.9, 5], [1.5, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.14, 22], [0.9, 14], [1.5, 0]]}]},
	&"dismiss": {"dur": 1.2, "seated": false, "arms": true, "free": true, "chan": [
		{"k": "arm_abduct", "keys": [[0, 0], [0.22, 24], [0.9, 18], [1.2, 0]]},
		{"k": "arm_flex", "keys": [[0, 0], [0.22, 14], [0.9, 8], [1.2, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.2, 52], [0.34, 30], [0.5, 56], [0.7, 36], [1.2, 0]]},
		{"k": "hand_flex", "keys": [[0, 0], [0.2, -20], [0.34, 8], [0.5, -22], [1.2, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.25, -55], [0.9, -55], [1.2, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.25, -55], [0.9, -55], [1.2, 0]]},
		{"k": "head_yaw", "keys": [[0, 0], [0.3, 7], [0.9, 7], [1.2, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.3, 3], [0.9, 3], [1.2, 0]]},
		{"k": "torso_yaw", "keys": [[0, 0], [0.3, 4], [0.9, 4], [1.2, 0]]}]},
	&"shrug": {"dur": 1.5, "seated": false, "arms": true, "both": true, "free": true, "chan": [
		{"k": "shoulder_raise", "keys": [[0, 0], [0.26, 9], [0.95, 9], [1.5, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.3, 12], [0.95, 12], [1.5, 0]]},
		{"k": "arm_flex", "keys": [[0, 0], [0.3, 6], [0.95, 6], [1.5, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.3, 40], [0.95, 40], [1.5, 0]]},
		{"k": "forearm_twist", "keys": [[0, 0], [0.3, 38], [0.95, 38], [1.5, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.3, -50], [0.95, -50], [1.5, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.3, -50], [0.95, -50], [1.5, 0]]},
		{"k": "head_tilt", "keys": [[0, 0], [0.3, 6], [0.95, 6], [1.5, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.3, -2], [0.95, -2], [1.5, 0]]}]},
	&"think": {"dur": 2.6, "seated": false, "arms": true, "free": true, "chan": [
		{"k": "arm_flex", "keys": [[0, 0], [0.7, 64], [1.9, 64], [2.6, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.7, -30], [1.9, -30], [2.6, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.7, 112], [1.9, 112], [2.6, 0]]},
		{"k": "head_yaw", "keys": [[0, 0], [0.6, -9], [1.9, -9], [2.6, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.6, -3], [1.9, -3], [2.6, 0]]},
		{"k": "head_tilt", "keys": [[0, 0], [0.6, 5], [1.9, 5], [2.6, 0]]}]},
	# ---- speaking gestures -----------------------------------------------------
	&"beat": {"dur": 0.6, "seated": true, "arms": true, "chan": [
		{"k": "elbow", "keys": [[0, 0], [0.14, 14], [0.3, 4], [0.6, 0]]},
		{"k": "arm_flex", "keys": [[0, 0], [0.14, 6], [0.3, 2], [0.6, 0]]},
		{"k": "hand_flex", "keys": [[0, 0], [0.12, -10], [0.3, 4], [0.6, 0]]}]},
	&"explain": {"dur": 2.2, "seated": false, "arms": true, "both": true, "chan": [
		{"k": "arm_flex", "keys": [[0, 0], [0.4, 14], [1.0, 20], [1.5, 14], [2.2, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.4, 8], [1.0, 14], [1.5, 8], [2.2, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.4, 48], [0.8, 60], [1.2, 44], [1.6, 56], [2.2, 0]]},
		{"k": "forearm_twist", "keys": [[0, 0], [0.4, 28], [1.5, 28], [2.2, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.4, -40], [1.7, -40], [2.2, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.4, -40], [1.7, -40], [2.2, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.6, 2], [1.6, 2], [2.2, 0]]}]},
	&"explain_small": {"dur": 1.5, "seated": true, "arms": true, "chan": [
		{"k": "arm_flex", "keys": [[0, 0], [0.3, 14], [0.8, 18], [1.5, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.3, 8], [0.8, 12], [1.5, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.3, 38], [0.6, 52], [0.9, 36], [1.5, 0]]},
		{"k": "forearm_twist", "keys": [[0, 0], [0.3, 26], [0.9, 26], [1.5, 0]]},
		{"k": "hand_flex", "keys": [[0, 0], [0.3, -8], [0.6, 6], [1.5, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.3, -35], [1.0, -35], [1.5, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.3, -35], [1.0, -35], [1.5, 0]]}]},
	&"open_palms": {"dur": 1.9, "seated": false, "arms": true, "both": true, "free": true, "chan": [
		{"k": "arm_abduct", "keys": [[0, 0], [0.4, 12], [1.4, 12], [1.9, 0]]},
		{"k": "arm_flex", "keys": [[0, 0], [0.4, 12], [1.4, 12], [1.9, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.4, 62], [1.4, 62], [1.9, 0]]},
		{"k": "forearm_twist", "keys": [[0, 0], [0.4, 48], [1.4, 48], [1.9, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.4, -55], [1.5, -55], [1.9, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.4, -55], [1.5, -55], [1.9, 0]]},
		{"k": "head_tilt", "keys": [[0, 0], [0.5, 4], [1.4, 4], [1.9, 0]]}]},
	&"point": {"dur": 1.9, "seated": false, "arms": true, "free": true, "chan": [
		{"k": "arm_flex", "keys": [[0, 0], [0.42, 82], [1.35, 82], [1.9, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.42, 6], [1.35, 6], [1.9, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.42, -38], [1.35, -38], [1.9, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.3, -70], [1.4, -70], [1.9, 0]]},
		{"k": "torso_yaw", "keys": [[0, 0], [0.42, -5], [1.35, -5], [1.9, 0]]},
		{"k": "torso_pitch", "keys": [[0, 0], [0.42, 2], [1.35, 2], [1.9, 0]]}]},
	&"warn": {"dur": 1.7, "seated": false, "arms": true, "free": true, "chan": [
		{"k": "arm_flex", "keys": [[0, 0], [0.4, 28], [1.2, 28], [1.7, 0]]},
		{"k": "arm_abduct", "keys": [[0, 0], [0.4, 26], [1.2, 26], [1.7, 0]]},
		{"k": "elbow", "keys": [[0, 0], [0.4, 62], [1.2, 62], [1.7, 0]]},
		{"k": "forearm_twist", "keys": [[0, 0], [0.4, -30], [1.2, -30], [1.7, 0]]},
		{"k": "hand_flex", "keys": [[0, 0], [0.4, -20], [1.2, -20], [1.7, 0]]},
		{"k": "fingers_curl", "keys": [[0, 0], [0.4, -55], [1.2, -55], [1.7, 0]]},
		{"k": "index_curl", "keys": [[0, 0], [0.4, -55], [1.2, -55], [1.7, 0]]},
		{"k": "torso_pitch", "keys": [[0, 0], [0.4, 4], [1.2, 4], [1.7, 0]]},
		{"k": "head_pitch", "keys": [[0, 0], [0.4, 6], [1.2, 6], [1.7, 0]]}]},
}

## Gestures that can be requested by name. Aliases map to canonical names.
const ALIASES := {
	&"agree": &"nod", &"agreement": &"nod", &"yes": &"nod",
	&"disagree": &"shake", &"disagreement": &"shake", &"no": &"shake",
	&"thinking": &"think", &"hesitate": &"think", &"hesitation": &"think",
	&"dismissive": &"dismiss", &"wave_off": &"dismiss",
	&"surprised": &"surprise", &"indicate": &"point", &"stop": &"warn", &"warning": &"warn",
	&"concern": &"tilt", &"curious": &"tilt", &"listen_nod": &"nod_small",
}

static func resolve(gesture_name: StringName) -> StringName:
	return ALIASES.get(gesture_name, gesture_name)

static func has_gesture(gesture_name: StringName) -> bool:
	return GESTURES.has(resolve(gesture_name))

static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in GESTURES.keys():
		out.append(String(k))
	return out
