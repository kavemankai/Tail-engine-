class_name BarEnvironmentController
extends Node3D
## Root script of BarInteriorEnvironment.tscn.
## Quality toggles for expensive effects plus lookup helpers for anchors.
## No gameplay, dialogue or character logic lives here.

@export_group("Effects")
@export var volumetric_fog := true:
	set(v): volumetric_fog = v; _apply()
@export var screen_space_reflections := true:
	set(v): screen_space_reflections = v; _apply()
@export var ambient_occlusion := true:
	set(v): ambient_occlusion = v; _apply()
@export var glow := true:
	set(v): glow = v; _apply()
@export var rain_particles := true:
	set(v): rain_particles = v; _apply()
@export var steam := true:
	set(v): steam = v; _apply()
@export var neon_flicker := true:
	set(v): neon_flicker = v; _apply()
@export var animated_screens := true:
	set(v): animated_screens = v; _apply()
@export var ambient_audio := true:
	set(v): ambient_audio = v; _apply()
@export var dynamic_shadows := true:
	set(v): dynamic_shadows = v; _apply()
@export_group("Integration")
## Disable if the host game supplies its own WorldEnvironment.
@export var use_bundled_world_environment := true:
	set(v): use_bundled_world_environment = v; _apply()


func _ready() -> void:
	_apply()


## "high", "medium" or "low".
func apply_quality_preset(preset: String) -> void:
	match preset:
		"low":
			volumetric_fog = false; screen_space_reflections = false; ambient_occlusion = false
			steam = false; rain_particles = false; dynamic_shadows = false
		"medium":
			volumetric_fog = false; screen_space_reflections = false; ambient_occlusion = true
			steam = true; rain_particles = true; dynamic_shadows = true
		_:
			volumetric_fog = true; screen_space_reflections = true; ambient_occlusion = true
			steam = true; rain_particles = true; dynamic_shadows = true


func get_anchor(anchor_name: String) -> Marker3D:
	return get_node_or_null("Anchors/NPC/" + anchor_name) as Marker3D


func get_interaction_point(point_name: String) -> Marker3D:
	return get_node_or_null("Anchors/Interaction/" + point_name) as Marker3D


func get_camera_marker(marker_name: String) -> Marker3D:
	return get_node_or_null("Anchors/Cameras/" + marker_name) as Marker3D


func get_restricted_door() -> BarSecurityDoor:
	return get_node_or_null("Interactive/RestrictedDoor") as BarSecurityDoor


func get_service_panel() -> BarServicePanel:
	return get_node_or_null("Interactive/ServicePanel") as BarServicePanel


func _apply() -> void:
	if not is_node_ready():
		return
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		if not use_bundled_world_environment:
			we.environment = null
		elif we.environment:
			var env := we.environment
			env.volumetric_fog_enabled = volumetric_fog
			env.ssr_enabled = screen_space_reflections
			env.ssao_enabled = ambient_occlusion
			env.glow_enabled = glow
	for n in get_tree().get_nodes_in_group("bar_rain"):
		if is_ancestor_of(n): n.emitting = rain_particles; n.visible = rain_particles
	for n in get_tree().get_nodes_in_group("bar_steam"):
		if is_ancestor_of(n): n.emitting = steam; n.visible = steam
	for n in get_tree().get_nodes_in_group("bar_flicker"):
		if is_ancestor_of(n): n.enabled = neon_flicker
	for n in get_tree().get_nodes_in_group("bar_audio"):
		if is_ancestor_of(n):
			if ambient_audio and not n.playing: n.play()
			elif not ambient_audio: n.stop()
	for n in get_tree().get_nodes_in_group("bar_shadow_light"):
		if is_ancestor_of(n): n.shadow_enabled = dynamic_shadows
	for n in get_tree().get_nodes_in_group("bar_animated"):
		if is_ancestor_of(n) and n is GeometryInstance3D:
			var m := (n as GeometryInstance3D).material_override as ShaderMaterial
			if m: m.set_shader_parameter("animated", animated_screens)
