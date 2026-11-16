# Cinematic Action Director

A Godot 4.6 addon for playable cinematics: timelines with timed inputs, choices and branching outcomes. An encounter is a stage scene and a sequence resource. Adding or changing one needs no script.

The examples use flat 2D shapes on purpose. They test the runtime, and the same stage code binds 3D nodes.

## Run it

Open `project.godot` in Godot 4.6 and run. Pick an example from the menu.

| Example | Keyboard | Gamepad |
|---|---|---|
| Bar fight | Space dodge, J stool / hold to shove, K back off | A, X, B |
| Alley chase | J jump, K roll, W / S high or low road | X, B, D-pad up / down |

R or Y replays. Escape or Start returns to the menu.

Both examples run through one host script, `examples/demo_host.gd`, which has no encounter-specific code.

## Test it

```bash
godot --headless --editor --path . --import
godot --headless --path . res://tests/run.tscn
```

The run prints PASS or FAIL per check and exits non-zero on any failure. Two warnings about invalid sequences are expected: the tests feed the director bad data to check it refuses.

## Use it in a game

Copy `addons/cinematic_action_director` into your project and read [docs/INTEGRATION.md](docs/INTEGRATION.md).

## Not built yet

- Adapters for a real game's player lock, dialogue system and saves. The director reports the outcome, the path taken and each gate result; the game stores them.
- A physical controller test. Tests inject gamepad events.
- Mash gates and analogue-stick directions.
- Paired contact animation. That is content work, and no director code replaces it.

`docs/research` holds the earlier Telltale and Godot addon research. Its file 05 describes a prototype that is not in this repository.
