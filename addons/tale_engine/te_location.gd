class_name TELocation
extends Node3D
## Root of a location scene. The engine finds things by name, so a real set
## replaces the greybox by keeping these names:
##   Marks/<name>   Marker3D   where cast members stand
##   Shots/<name>   Camera3D   dialogue and wide shots
##   Hubs/<name>    TEHub      hotspots for a walk-around step
##   Zones/<name>   TECameraZone, optional fixed cameras for hubs
##   <name>         CADStage   encounter stages, direct children

func mark(id: StringName) -> Node3D:
	return get_node_or_null("Marks/%s" % id) as Node3D

func shot(id: StringName) -> Camera3D:
	return get_node_or_null("Shots/%s" % id) as Camera3D

func hub(id: StringName) -> TEHub:
	return get_node_or_null("Hubs/%s" % id) as TEHub

func stage(id: StringName) -> CADStage:
	return get_node_or_null(NodePath(id)) as CADStage

func zones() -> Array[Node]:
	var holder := get_node_or_null(^"Zones")
	return holder.get_children() if holder != null else []
