class_name ConversationProfile
extends Resource
## Per-character tuning for the shared ConversationAnimationController.
## All clip names refer to the Humanoid Kit's in-place library.

@export var display_name := "Character"

@export_group("Base clips (Humanoid Kit library)")
@export var idle_clip: StringName = &"Idle"
## Used when the idle clip folds the arms; gestures that need free arms switch to this.
@export var free_arms_clip: StringName = &"Idle"
@export var listen_clip: StringName = &"Idle"
@export var talk_clip: StringName = &"Idle_Talking"
## Used for serious / restrained speech instead of the expressive talk clip.
@export var talk_restrained_clip: StringName = &"Idle"
@export var seated_idle_clip: StringName = &"Sitting_Idle"
@export var seated_talk_clip: StringName = &"Sitting_Talking"
@export var walk_clip: StringName = &"Walk"
@export var talk_speed := 1.0

@export_group("Gesture tuning")
@export var gesture_scale := 1.0
@export var arm_gesture_scale := 1.0
@export var head_motion_scale := 1.0
@export var breathing_scale := 1.0
## Characters that keep arms folded while talking should not use arm beats.
@export var arm_beats_while_speaking := true
@export var speaking_gestures: PackedStringArray = PackedStringArray(["beat", "explain_small", "nod_small", "explain"])
@export var listening_gestures: PackedStringArray = PackedStringArray(["nod_small", "tilt", "glance_away"])
@export var seated_speaking_gestures: PackedStringArray = PackedStringArray(["beat", "explain_small", "nod_small"])
## Empty = every gesture allowed. Otherwise only these names (and aliases of them).
@export var allowed_gestures: PackedStringArray = PackedStringArray()

@export_group("Look and turning")
@export var look_max_yaw_deg := 70.0
@export var look_max_pitch_deg := 30.0
@export var look_speed := 6.0
@export var body_turn_threshold_deg := 38.0
@export var body_turn_speed := 4.5
@export var step_turn := true

@export_group("Seating")
## Height of the seat surface above the floor that Sitting_Idle expects.
@export var seat_height := 0.45
## How far behind the body origin (along its facing) the pelvis settles when seated.
@export var seat_back_offset := 0.29
