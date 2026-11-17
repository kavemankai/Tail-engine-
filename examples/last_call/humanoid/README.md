# Humanoid prototype integration

The Episode 0 cast now instantiates the imported PlayerCharacter, Rook and Juno through a TEActor adapter. The outer body remains under Flow and the exploration controller; the child kit physics is disabled. Movement velocity drives the kit's locomotion and CAD clip calls dispatch to provisional in-place animations. The Episode 0 cast is also used by many QTE lab examples. The target/cinematic fixture cast remains unchanged so its special sockets are preserved.

The clip mappings are stand-ins: guard, hits, dodges and grapples are not matched paired contact choreography. They need authored clips, retargeting and contact review. Audio is unvoiced. Physical controller, production quality and all route-specific visual results have not been accepted.

The bar is greybox geometry. An earlier trial of a full bar environment has been removed from the repository.

Open with Godot 4.6.3 and matching export templates. `examples/last_call/humanoid/demo_capture.tscn` is an automated capture: it moves the player in the bar, then enters the directional counter lab and deliberately does not respond to the prompt. `adapter_probe.gd` checks QTE dispatch to each rig. From the project root, run `python tools/verify.py --godot <path-to-godot>` for the regression suite.
