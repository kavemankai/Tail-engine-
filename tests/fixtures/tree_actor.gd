extends TEActor
## Minimal two-bone AnimationTree/OneShot adapter, not a replacement humanoid.

var rig := Skeleton3D.new()
var tree := AnimationTree.new()
var clips: Array[StringName] = []
var _action := AnimationNodeAnimation.new()

func _ready() -> void:
	rig.name = "Rig"
	rig.add_bone("root")
	rig.add_bone("hand")
	rig.set_bone_parent(1, 0)
	rig.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0.5, 1.0, 0)))
	add_child(rig)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.root_node = NodePath("..")
	add_child(player)
	var library := AnimationLibrary.new()
	for clip: StringName in [&"idle", &"block", &"dodge", &"hit_react", &"windup"]:
		var animation := Animation.new()
		animation.length = 1.0
		if clip == &"idle":
			animation.loop_mode = Animation.LOOP_LINEAR
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Rig:hand"))
		animation.track_insert_key(track, 0.0, Quaternion.IDENTITY)
		animation.track_insert_key(track, 0.5, Quaternion(Vector3.FORWARD, 0.7 if clip != &"idle" else 0.0))
		animation.track_insert_key(track, 1.0, Quaternion.IDENTITY)
		library.add_animation(clip, animation)
	player.add_animation_library(&"", library)
	var blend := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"idle"
	_action.animation = &"block"
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.08
	shot.fadeout_time = 0.08
	blend.add_node(&"Idle", idle)
	blend.add_node(&"Action", _action)
	blend.add_node(&"OneShot", shot)
	blend.connect_node(&"output", 0, &"OneShot")
	blend.connect_node(&"OneShot", 0, &"Idle")
	blend.connect_node(&"OneShot", 1, &"Action")
	tree.name = "AnimationTree"
	tree.tree_root = blend
	tree.anim_player = NodePath("../AnimationPlayer")
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(tree)
	tree.active = true
	tree.advance(0.0)

func play_clip(clip: StringName) -> void:
	clips.append(clip)
	_action.animation = clip
	tree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	tree.advance(0.0)
