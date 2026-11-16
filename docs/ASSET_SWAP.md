# Replacing the placeholders

The engine finds content by name, so each placeholder is replaced by supplying the real thing under the same name. No engine script changes.

## Characters

A character is a `TECharacter` in `cast.tres`. With `actor_scene` empty it gets the placeholder capsule.

1. Make a scene whose root is a `CharacterBody3D` with a script that extends `TEActor`. Put your rig under it, feet at the origin, facing -Z.
2. Override two methods:

```gdscript
extends TEActor

@onready var tree: AnimationTree = $AnimationTree

func play_clip(clip: StringName) -> void:
	tree["parameters/Action/transition_request"] = clip    # however your rig plays a one-shot

func speak(talking: bool) -> void:
	tree["parameters/Talk/blend_amount"] = 1.0 if talking else 0.0
```

3. Set the scene as `actor_scene` on the character.
4. Fill `clips`: the logical name a timeline uses (`dodge`, `hit_react`, `windup`) mapped to your animation's real name. Unmapped names are passed through unchanged.

Timelines move the actor's root transform. Your clips should play in place unless a timeline leaves the slot still for that beat.

The player character gets a controller added for walk-around steps. It moves the `CharacterBody3D`; drive your locomotion blend from `velocity` in your actor script.

`tests/fixtures/tree_actor.gd` is a minimal two-bone AnimationTree/OneShot adapter
fixture. Tests drive both player and NPC through `CADStage.act`, verify a mapped
skeletal clip changes pose, and check skeletal playback does not double-apply the
stage's root displacement. It is not a humanoid rig or a contact-quality test.
No real humanoid/paired animation assets are present in this checkout. Before
production use, validate the actual kit's locomotion lock, retargeting/rest poses,
foot placement, contact frames, branch blends and socket attachments.

## Sets

Replace the boxes under a location's `Set` node with your geometry and collision. Keep the names under `Marks`, `Shots`, `Hubs` and `Zones`, and move them to suit the new set. Run the validator; it lists any name a step or dialogue file still expects.

## Voice

Set `voice_dir` on a character to a folder. A line tagged `[ID:e0_014]` plays `e0_014.ogg` (or `.wav`, `.mp3`) from the speaker's folder and holds for the file's length. A line with no file holds for a time based on its length, so voice can arrive a few lines at a time. The validator prints how many lines have files.

## Action scenes

A stage scene's slots are plain markers; the cast is bound to them at run time. To restage a fight for real animation, edit the timelines in the stage's `AnimationPlayer`: move the slot keys to match your clips' footwork, and add `act("Player", "clip")` method keys where each clip should start. Props that the timeline moves, like the stool, are nodes in the stage scene; replace the mesh and keep the node name.

## Music and sound

`Audio.music(stream)` crossfades to a track, and `Audio.effect(stream)` plays a one-shot. Call them from dialogue files (`do Audio.music(...)`) or timeline method tracks. Timelines can also use Godot's own audio tracks.

## Screen text and prompts

The conversation box is `addons/tale_engine/te_balloon.gd` and the rest of the overlay is `te_screen.gd`. Both build plain controls in code. Restyle them there, or replace their node construction with your own scenes while keeping the public methods.

## Scoped cinematic playback on an AnimationTree

For scenes using `CADBeat.playback_scale`, the actor adapter must expose:

```gdscript
func cad_supports_playback_scale() -> bool:
    return true

func cad_playback_speed() -> float:
    return float(tree.get("parameters/CinematicSpeed/scale"))

func cad_set_playback_speed(speed: float) -> void:
    tree.set("parameters/CinematicSpeed/scale", speed)
```

Insert a TimeScale node at the appropriate point in your existing tree. The fixture
places it after its OneShot, retaining the humanoid adapter contract. CAD captures
the existing speed, applies a local multiplier and restores it on unbind, terminal
exit, cancellation and unloading. AnimationPlayer-only actors use TEActor's default
hooks. A bound AnimationTree actor without these hooks is rejected for slowdown.
Root displacement stays in the stage timeline; skeletal clips remain in place.
Voice playback is intentionally independent. Validate the actual rig's node paths,
blends, paired timing and contact; the two-bone fixture is interface evidence only.
