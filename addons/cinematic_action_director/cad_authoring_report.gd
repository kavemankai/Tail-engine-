class_name CADAuthoringReport
extends RefCounted
## Structural/stage errors plus conservative graph warnings. Warnings do not
## reject intentional gated retries or change existing encounter compatibility.

static func inspect(sequence: CADSequence, stage: CADStage = null) -> Dictionary:
	if sequence == null:
		return {"errors": PackedStringArray(["Missing sequence."]), "warnings": PackedStringArray(), "beats": 0, "gates": 0, "families": []}
	var errors := CADDirector.validation_errors(sequence, stage)
	var warnings := PackedStringArray()
	var by_id := {}
	var edges := {}
	var families := PackedStringArray()
	var gates := 0
	for beat in sequence.beats:
		if beat == null:
			continue
		by_id[beat.id] = beat
		var exits: Array[StringName] = []
		if beat.gate == null:
			exits.append(beat.next)
			for branch in beat.branches:
				if branch != null: exits.append(branch.next)
		else:
			gates += 1
			exits.append(beat.gate.timeout_next)
			for option in beat.gate.options:
				if option != null: exits.append(option.next)
			var family := "legacy"
			if beat.gate.interaction != null:
				var spec := beat.gate.interaction
				if spec.family >= 0 and spec.family < CADInteractionSpec.Family.size():
					family = CADInteractionSpec.Family.keys()[spec.family]
				for destination: StringName in spec.routes.values(): exits.append(destination)
			if family not in families: families.append(family)
		edges[beat.id] = exits
	var reachable := {}
	var pending: Array = [sequence.entry]
	while not pending.is_empty():
		var id: StringName = pending.pop_back()
		if reachable.has(id): continue
		reachable[id] = true
		for destination: StringName in edges.get(id, []): pending.append(destination)
	for id: StringName in by_id:
		if not reachable.has(id): warnings.append("Unreachable beat: %s" % id)
	for outcome in sequence.outcomes:
		if not reachable.has(outcome): warnings.append("Unreachable outcome: %s" % outcome)
	# Kahn reduction on the ungated subgraph. Remaining nodes contain a possible
	# automatic cycle or depend on one; timeline side effects cannot be inferred.
	var incoming := {}
	for id: StringName in by_id:
		if by_id[id].gate == null: incoming[id] = 0
	for id: StringName in incoming:
		for destination: StringName in edges[id]:
			if incoming.has(destination): incoming[destination] += 1
	var ready: Array = []
	for id: StringName in incoming:
		if incoming[id] == 0: ready.append(id)
	while not ready.is_empty():
		var id: StringName = ready.pop_back()
		incoming.erase(id)
		for destination: StringName in edges[id]:
			if incoming.has(destination):
				incoming[destination] -= 1
				if incoming[destination] == 0: ready.append(destination)
	for id: StringName in incoming:
		warnings.append("Possible ungated cycle or dependency: %s; confirm a bounded exit." % id)
	warnings.sort()
	families.sort()
	return {"errors": errors, "warnings": warnings, "beats": by_id.size(), "gates": gates, "families": families}
