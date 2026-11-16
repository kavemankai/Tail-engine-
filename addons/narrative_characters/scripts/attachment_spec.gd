class_name AttachmentSpec
extends Resource
## A rigid mesh parented to one bone of the Humanoid Kit skeleton (hair, glasses, bags).
@export var bone_name: StringName = &"Head"
@export var mesh: Mesh
@export var material: Material
## Transform in the bone's local space (built from rest-pose coordinates by the builder).
@export var transform := Transform3D.IDENTITY
