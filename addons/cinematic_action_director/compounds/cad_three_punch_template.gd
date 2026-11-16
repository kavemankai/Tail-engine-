class_name CADThreePunchTemplate
extends CADChainTemplate
## Three separately acquired inputs and three separately authored paired clips.
## Shared chain compiler handles outcomes, interruption and resource isolation.

func build() -> CADSequence:
	if gates.size() != 3 or action_timelines.size() != 3 \
			or action_timelines[0] == action_timelines[1] or action_timelines[0] == action_timelines[2] \
			or action_timelines[1] == action_timelines[2]:
		last_errors = PackedStringArray(["Three-punch combo needs exactly three gates and three distinct action timelines."])
		return null
	return super.build()
