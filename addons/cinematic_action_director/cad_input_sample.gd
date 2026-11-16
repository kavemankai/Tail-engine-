class_name CADInputSample
extends RefCounted
## A logical edge, with no retained InputEvent or scene reference.
enum Kind { EDGE, DIRECTION }
var kind: Kind = Kind.EDGE
var vector := Vector2.ZERO
var started := false
var action: StringName
var pressed := false
var strength := 0.0
var device := -1
var at := 0.0
