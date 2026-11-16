class_name CharacterAppearance
extends Resource
## Visual variant applied on top of the UNMODIFIED Humanoid Kit glTF at runtime.
## Same skeleton, same skin, same bone names: only meshes and colours differ.

## Replaces the kit body mesh (same vertices and weights, with per-vertex skin/underwear colours).
@export var body_mesh: Mesh
## Clothing shells skinned with the body's own Skin, so they deform identically.
@export var skinned_parts: Array[Mesh] = []
## Rigid meshes attached to bones (hair, glasses, bags).
@export var attachments: Array[AttachmentSpec] = []
## Kit mesh nodes to hide (texture-dependent eyebrow cards).
@export var hidden_nodes: PackedStringArray = PackedStringArray(["Eyebrows"])
## Restrained proportion adjustment, applied to the model root (skeleton is untouched).
@export var model_scale := Vector3.ONE
## Anchors in Head-bone space: name -> Transform3D. Exposed as unique-name nodes (%EyeFocus).
@export var head_anchors := {}
