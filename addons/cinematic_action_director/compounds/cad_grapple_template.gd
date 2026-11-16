class_name CADGrappleTemplate
extends CADChainTemplate
## Direction/pressure/release choreography uses the ordinary chain compiler.
## Require pressure before the final timed release, with authored recoveries.

func build() -> CADSequence:
	if gates.size() < 2 or gates[-1] == null or gates[-1].interaction == null \
			or gates[-1].interaction.family != CADInteractionSpec.Family.GESTURE \
			or gates[-1].interaction.gesture != CADInteractionSpec.Gesture.TIMED_RELEASE \
			or not gates.slice(0, -1).any(func(gate: CADGate) -> bool: return gate != null and gate.interaction != null and gate.interaction.family == CADInteractionSpec.Family.PRESSURE):
		last_errors = PackedStringArray(["Grapple needs pressure followed by a final timed-release gate."])
		return null
	return super.build()
