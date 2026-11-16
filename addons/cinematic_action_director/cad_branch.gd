class_name CADBranch
extends Resource
## A flag-conditioned exit for an ungated beat. The first branch whose flag
## holds wins; otherwise the beat's `next` is used.

## Key in CADDirector.flags. Prefix with "!" to require it unset.
@export var requires: StringName
## A beat ID or a terminal outcome.
@export var next: StringName
