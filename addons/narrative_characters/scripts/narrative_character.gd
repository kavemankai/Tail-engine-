extends "res://addons/humanoid_kit/scripts/humanoid.gd"
## A Humanoid Kit body (CharacterBody3D) with the conversation controller attached.
##
## Scene layout (see scenes/NarrativeCharacter.tscn):
##   NarrativeCharacter (this script, extends the kit's humanoid.gd)
##   |- Capsule             kit collision shape
##   |- Visual              narrative_animator.gd (extends the kit's animator.gd)
##   '- ConversationController  ConversationAnimationController
##
## The kit's own movement API (set_move_direction, set_move_speed, play_action, ...)
## is unchanged. Conversation behaviour is reached through `conversation`.
const Profile := preload("conversation_profile.gd")

@export var profile: Resource
@export var appearance: Resource   # CharacterAppearance

@onready var conversation: ConversationAnimationController = $ConversationController
@onready var capsule: CollisionShape3D = $Capsule

const STAND_HEIGHT := 1.82
const SEATED_HEIGHT := 1.0

func _ready() -> void:
	# Each instance needs its own capsule so seating one does not resize the others.
	capsule.shape = capsule.shape.duplicate()
	if profile == null:
		profile = Profile.new()
	animator.profile = profile
	animator.appearance = appearance
	super._ready()
	rotation_speed = profile.body_turn_speed
	conversation.setup(self, animator)
	conversation.seated_changed.connect(_on_seated_changed)

func get_conversation() -> ConversationAnimationController:
	return conversation

## Eye focus marker (world position to aim cameras / other characters' look targets at).
func get_eye_focus() -> Node3D:
	return conversation.get_eye_focus()

## Place the character on a seat and play the sit-down. `seat` is a Node3D at the centre of
## the seat surface; its +Z axis is the direction the character will face.
func sit_on(seat: Node3D, play_sit_animation: bool = true) -> void:
	if not is_inside_tree() or not is_node_ready():
		push_error("NarrativeCharacter.sit_on() needs the character to be in the scene tree and ready")
		return
	var yaw := seat.global_rotation.y
	var facing := Vector3(sin(yaw), 0.0, cos(yaw))
	global_position = seat.global_position + facing * profile.seat_back_offset - Vector3.UP * profile.seat_height
	rotation.y = yaw
	velocity = Vector3.ZERO
	if play_sit_animation:
		conversation.set_seated(true)
	else:
		stance = &"sit"
		conversation.seated = true
		conversation.seated_changed.emit(true)

func stand_up() -> void:
	conversation.set_seated(false)

func _on_seated_changed(is_seated: bool) -> void:
	var shape := capsule.shape as CapsuleShape3D
	if shape == null:
		return
	shape.height = SEATED_HEIGHT if is_seated else STAND_HEIGHT
	capsule.position.y = shape.height * 0.5   # keep the capsule bottom on the floor
