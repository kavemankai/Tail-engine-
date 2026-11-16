extends TEActor
## Greybox stand-in: a coloured capsule with a nose for facing and a label that
## shows the clip it was asked to play, so timing is visible without animation.

var _material := StandardMaterial3D.new()
var _label := Label3D.new()
var _clip_timer := 0.0
var _talking := false
var _clock := 0.0
## Clips received, newest last. Tests read this.
var clip_log: Array[StringName] = []

func _init() -> void:
	# Validators instantiate and dispose actors without entering the scene tree.
	# Own this node immediately so disposal before _ready cannot leak it.
	add_child(_label)

func setup(new_character: TECharacter) -> void:
	super(new_character)
	_material.albedo_color = character.colour
	_label.text = character.display_name

func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	body.material_override = _material
	add_child(body)
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 0.14, 0.3)
	nose.mesh = box
	nose.position = Vector3(0, 1.5, -0.35)
	nose.material_override = _material
	add_child(nose)
	var shape := CollisionShape3D.new()
	var collider := CapsuleShape3D.new()
	collider.radius = 0.3
	collider.height = 1.8
	shape.shape = collider
	shape.position.y = 0.9
	add_child(shape)
	_label.position.y = 2.1
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48

func play_clip(clip: StringName) -> void:
	clip_log.append(clip)
	_label.text = "%s\n[%s]" % [character.display_name, clip]
	_clip_timer = 0.7
	if clip == &"hit_react":
		_material.albedo_color = Color(1, 0.25, 0.25)

func speak(talking: bool) -> void:
	_talking = talking

func _process(delta: float) -> void:
	_clock += delta
	_label.position.y = 2.1 + (0.06 * sin(_clock * 14.0) if _talking else 0.0)
	if _clip_timer > 0.0:
		_clip_timer -= delta
		if _clip_timer <= 0.0:
			_label.text = character.display_name
			_material.albedo_color = character.colour
