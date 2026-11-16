extends TEActor
## Prototype adapter: the outer body belongs to Flow; the kit supplies visuals.

const CHARACTERS := {
	&"player": preload("res://addons/narrative_characters/scenes/PlayerCharacter.tscn"),
	&"stranger": preload("res://addons/narrative_characters/scenes/Rook.tscn"),
	&"bartender": preload("res://addons/narrative_characters/scenes/Juno.tscn"),
}
const CLIPS := {
	&"windup": &"Punch_Jab", &"guard": &"Hit_Chest", &"hit_react": &"Hit_Chest",
	&"dodge": &"Roll", &"counter": &"Punch_Jab", &"punch_jab": &"Punch_Jab",
	&"punch_cross": &"Punch_Jab", &"punch_hook": &"Punch_Jab",
	&"recoil_jab": &"Hit_Chest", &"recoil_cross": &"Hit_Chest", &"recoil_hook": &"Hit_Chest",
	&"grapple_struggle": &"Hit_Chest", &"grapple_escape": &"Roll", &"grapple_release": &"Hit_Chest",
	&"grapple_stagger": &"Hit_Chest", &"grab": &"Interact",
}
var body: CharacterBody3D
var cinematic_speed := 1.0
var clip_log: Array[StringName] = []

func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)
	var selected: PackedScene = CHARACTERS.get(character.id if character != null else &"player", CHARACTERS[&"player"])
	body = selected.instantiate()
	body.collision_layer = 0
	body.collision_mask = 0
	add_child(body)
	body.set_physics_process(false)
	body.rotation.y = PI

func _physics_process(_delta: float) -> void:
	if is_instance_valid(body):
		body.animator.update_motion(Vector2(velocity.x, velocity.z).length(), true, &"neutral", false)
		if cinematic_speed != 1.0:
			body.animator.player.speed_scale = cinematic_speed

func play_clip(clip: StringName) -> void:
	clip_log.append(clip)
	if is_instance_valid(body):
		body.play_action(CLIPS.get(clip, clip))

func speak(talking: bool) -> void:
	if is_instance_valid(body):
		body.conversation.set_conversation_mode(talking)
		body.conversation.set_speaking(talking)

func cad_supports_playback_scale() -> bool:
	return true

func cad_playback_speed() -> float:
	return cinematic_speed

func cad_set_playback_speed(speed: float) -> void:
	cinematic_speed = speed
	if is_instance_valid(body) and is_instance_valid(body.animator.player):
		body.animator.player.speed_scale = speed
