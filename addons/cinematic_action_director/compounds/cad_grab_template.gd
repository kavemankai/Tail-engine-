class_name CADGrabTemplate
extends CADChainTemplate
## One Target gate followed by an authored reach/use/drop timeline. Timelines
## call attach_selected_prop/detach_selected_prop with result beat input_1.

func build() -> CADSequence:
	if gates.size() != 1 or gates[0] == null or gates[0].interaction == null \
			or gates[0].interaction.family != CADInteractionSpec.Family.TARGET:
		last_errors = PackedStringArray(["Grab needs exactly one Target gate."])
		return null
	return super.build()
