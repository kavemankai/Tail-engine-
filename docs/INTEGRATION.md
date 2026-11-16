# Cinematic Action Director reference

The action layer. Godot 4.6, GDScript only, no dependencies. It works without Tale Engine; inside an episode, Tale Engine starts it for you (see [AUTHORING.md](AUTHORING.md)).

## The parts

| Class | What it is |
|---|---|
| `CADStage` | Root node of an encounter scene. Its children are the slots that timelines animate: actors, props, cameras. It owns an `AnimationPlayer` holding one animation per beat. |
| `CADSequence` | Resource. The graph: an entry beat, the beats, and the named terminal outcomes. |
| `CADBeat` | Resource. One timeline, an optional gate, and where to go next. |
| `CADGate` | Resource. A timed window with one or more options and a timeout exit. |
| `CADOption` | Resource. An InputMap action, press or hold, an optional required flag, and its exit. |
| `CADBranch` | Resource. A flag and an exit, checked on an ungated beat before its `next`. Lets earlier choices redirect a scene. |
| `CADDirector` | Node. Runs a sequence on a stage. |
| `CADPrompt` | Helper that shows the open gate's options on a Label and a progress bar, with key or pad names read from the InputMap. |

A reaction to success or failure is a beat of its own. A missed dodge goes to a `hit` beat, which leads on to the same next beat as `evade`. That is how an encounter fails forward.

## Build an encounter

1. Make a scene with a `CADStage` root. Add a child node per role (`Player`, `Aggressor`, `Stool`, `Close`) and an `AnimationPlayer`.
2. Author one animation per beat. Tracks address the slots by name, so the scene works wherever it is instanced.
3. Add a method track on the stage root for the calls below.
4. Make a `CADSequence` resource that names those animations as beat timelines and wires the exits.

Method-track calls on the stage:

| Call | Effect |
|---|---|
| `marker(&"gate")` | Opens the beat's gate, if its `open_marker` is `gate`. Any name works. |
| `marker(&"done")` | Ends the timeline early. Reaching the end of the animation does the same. |
| `cut(&"Close")` | Makes that camera slot current. Works for Camera2D and Camera3D. |
| `act(&"Player", &"jab")` | Plays a clip on a role: calls `cad_act(clip)` if the node has it, else uses the node's `AnimationPlayer`, else plays it if it is an audio player. |

Gate timing has two modes. With `cut_on_resolve` on, the next beat starts the moment the player presses; use `blend_seconds` on the next beat to smooth it. With it off, the timeline plays to its end first, so the branch always starts from a known pose.

A looping timeline needs a gate that cuts on resolve. Use that for a held struggle or a waiting stance.

## Run it

```gdscript
var director := CADDirector.new()
add_child(director)
CADPrompt.bind(director, prompt_label, timer_bar)
director.finished.connect(_on_encounter_finished)

stage.bind(&"Player", player)          # optional: your actor follows the slot
director.flags = {&"stool_available": true}
director.begin(sequence, stage, _lock_player, _unlock_player)
```

`begin` validates everything first and returns false with a warning listing each problem: missing timelines, markers, roles, InputMap actions or exits.

`acquire` must return true once the game has given up control. `release` receives the outcome and runs once per run, whether the encounter ended, was cancelled or hit the watchdog.

After `finished(outcome)`:

- `director.trail` lists the beats entered, in order.
- `director.results` maps each gated beat to the chosen option ID or `&"timeout"`.

Store what you need from those in your own save data and use them to pick the next dialogue line.

## Binding real actors

A slot is any node under the stage. Timelines move slots. `stage.bind(role, actor)` makes an actor elsewhere in the tree follow its slot for the length of the encounter, through a `RemoteTransform2D` or `RemoteTransform3D` that the stage removes on release. `act()` goes to the bound actor.

The stage restores the camera that was current before the encounter. If there was none, the last shot stays.

## Control while running

| Call | Effect |
|---|---|
| `cancel()` | Ends with `&"cancelled"` and releases. |
| `suspend(true)` | Freezes the gate clock, the watchdog and the timeline, and ignores input and markers. |
| `window_scale` | Multiplies every gate window. Use it for an accessibility setting. |
| `flags` | Dictionary read by `CADOption.requires` and `CADBranch.requires`. An option whose flag is missing is not offered. A gate with no available option takes its timeout exit at once. Prefix a name with `!` to require it unset. |

Reserved outcomes: `cancelled`, `watchdog`, `staging_error`.

Every beat has a watchdog. A beat with a timeline or a self-ending gate gets one derived from its lengths plus five seconds. A beat the host drives must set `watchdog_seconds`.

A press made up to `buffer_seconds` before a gate opens still counts.

## Driving beats without a stage

Leave `timeline` empty and send markers yourself. `beat_started(beat, visit)` gives a visit number; pass it back with `director.marker(id, visit)`. A marker with an old number is rejected, so a delayed callback from an earlier beat or run cannot affect the current one.
