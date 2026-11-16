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

## Optional v2 interactions

Set `CADGate.interaction` to a `CADInteractionSpec` to opt into the shared runner.
Leave it null to retain the original press/hold, buffer and frozen-hold-window
behaviour. Episode 0's existing encounter resources remain unchanged.

Supported families are `GESTURE` (press/hold/timed-release/chord), `CHOICE`, `TIMING`
and `PASSIVE`. Gesture specs name a stable `id`, `actions` and an `option_id` referencing a gate
option. Choice specs use the gate's offered options. `monitored_actions` declares
additional wrong-input actions; `wrong_input` either ignores them or resolves
`miss`. Unrelated controls are ignored. `routes` optionally maps a result grade to
a destination in the **same** CADSequence; otherwise the selected option's `next`
or the gate's `timeout_next` is used. Specs are copied at acquisition.

`CADInteractionRunner` owns one evaluator, `CADInputRouter` and `CADClock` per
gate. Its `resolved(CADResult)` fires once. `CADDirector.interaction_resolved`
exposes the typed result; `detailed_results[beat_id]` retains the latest detail.
`result.to_dict()` contains scalar IDs, grade, route, progress and timing error.
Legacy `director.results` and `Story.results` keep option/timeout strings. Typed
details are currently encounter-local; no save migration or mid-QTE save exists.

New gates use monotonic **real active seconds**, independent of Engine.time_scale.
The deadline is exclusive: input at or after it times out, including after a frame
hitch. Holds must complete inside the window; unlike legacy holds, they do not
extend it. Accessibility `window_scale` scales the window. Scene pause and explicit
`suspend` exclude wall time. Resuming requires fresh input for incomplete holds.
Early input buffering remains a legacy-only feature in this milestone.

`CADInputRouter` reads current InputMap bindings, ignores echoes/repeated edges,
and blocks actions held on acquisition until released. The first matching pad
owns that gate unless `controller_device` is configured; other pads cannot release
or finish its inputs. Keyboard switching remains available. Losing the owning pad
cancels the active typed encounter. `Flow` prevents a concurrent dialogue balloon
from acquiring action input; concurrent dialogue is a later integration phase.

For deterministic tests, pass a seconds callable to `CADInteractionRunner.new`
or set `director.clock_source` before begin. Keep run/visit IDs when feeding a
runner directly; stale tokens are rejected. New evaluators extend
`CADInteractionHandler` and return pending `{}` or one small result dictionary.
Register each family in the runner and validator; do not put choreography or Story
writes in a handler.

### Directional dodge, block and selection

`family = DIRECTION` uses `direction_actions` in left/right/up/down order. The
defaults are `cad_dir_left/right/up/down`, mapped to WASD, left stick and D-pad.
All bindings remain in InputMap; the evaluator contains no fixed button or axis.
`FLICK` accepts a fresh neutral-to-active deflection; `HOLD` maintains that sector
for `hold_seconds`; `SELECT` maps `direction_options` sector IDs to offered gate
option IDs. Fixed-direction modes use `direction_sector` and `option_id`.

Sector IDs run clockwise: Up=0, UpRight=1, Right=2, DownRight=3, Down=4,
DownLeft=5, Left=6, UpLeft=7. Four-way mode uses the even IDs; enable
`direction_eight_way` for diagonals. Angular ties choose clockwise. The selected
sector is available as `CADResult.direction` and in its scalar dump.

Raw stick strength uses `direction_activation` (default 0.65) and
`direction_rearm` (0.25). The helper bypasses InputMap's deadzone rescaling so those
thresholds are literal. Activation is radial; rearm requires every bound component
to be at or below the neutral threshold. Pre-held directions, source switches and retries require
neutral first; opposing held controls do not count as neutral. A 25 ms configurable
`direction_settle_seconds` coalesces separately delivered axes/keys before judging
a sector. This prevents diagonal gestures failing on their first cardinal event.
Directional hold duration starts after settling; interrupted blocks reset and
require neutral. Keyboard, each pad's buttons and each stick pair never mix vectors.

`direction_space = INPUT` uses physical screen-relative controls. `CAMERA` rotates
them into world XZ (+X right, -Z up), using a planar camera-forward snapshot at
gate acquisition. Cuts during the gate cannot flip controls or prompts. The
director supplies the active Camera3D yaw (or Camera2D rotation); a camera must be
active before opening. Direct runners supply `context = {"camera_forward": Vector2}`
to `begin`; missing/invalid camera context returns false with `last_error`.

For deterministic held-input tests, pass an optional held-event snapshot callable
to `CADInteractionRunner.new(clock_source, input_snapshot)`, or set the director's
`input_snapshot`. Events are immediately normalised, never stored in results or
saves. Normal runtime samples actual held keyboard/pad state. Physical-controller
verification is still required separately from these synthetic-event tests.

### Timing, release, chords and restraint

| Spec field | Meaning |
|---|---|
| `gesture = TIMED_RELEASE` | One fresh press arms the challenge; the matching source's release is graded. A held button from before acquisition cannot arm it. |
| `gesture = CHORD` | `actions` contains 2–4 unique actions. They must overlap within `chord_seconds`; repeated presses do not count as another button. |
| `family = TIMING` | One press is graded around `ideal_seconds`. Parry is an authored use of this evaluator, not a separate combat system. |
| `perfect_seconds / success_seconds / partial_seconds` | Ordered, inclusive absolute-error bounds; anything later/outside them is `miss`. Input before the earliest partial bound follows `wrong_input`. |
| `timing_marker` | Optional, one-shot timing anchor after gate opening. `ideal_seconds` is then an offset from that marker; before the marker, input follows the early policy. Empty uses gate opening. |
| `family = PASSIVE` | `actions` is the forbidden set. A forbidden press or a forbidden action already held on acquisition yields `miss`; completing `passive_seconds` yields `restrained`. |

Timed release uses the same accuracy bounds as Timing. Too-early release with
IGNORE disarms the gesture and permits a fresh attempt; FAIL resolves `miss`.
For a failed chord with IGNORE, release its buttons and try again. With FAIL,
exceeding the chord tolerance resolves `miss` immediately. A different device
cannot release an action latched by the original physical source.

`window_scale` widens accuracy/chord tolerances as well as the overall deadline.
It does **not** shift the ideal/contact instant, lengthen hold/neutral durations,
or slow animations. A continuous hold completed before a frame hitch retains its
success. Neutral completion at the deadline is an explicit Passive success; an
input edge at that deadline is late. Choreography markers must fit after gate
opening and inside the authored window; the stage validator checks their names
and chronology. Host-driven markers still require the current visit token.

For graded follow-through, use `routes = {&"perfect": &"strong_reaction",
&"partial": &"glancing_reaction", &"miss": &"recovery"}` with those destinations
declared as ordinary beats/outcomes. The input handler never invokes actor or NPC
clips. The selected beat's timeline calls `CADStage.act` and `cut` as before.

## Compound resources

`CADCompoundAction.build()` produces a fresh `CADSequence`; it is an authoring
extension point, not a second graph runner. Assign either `TEStep.sequence` or
`TEStep.compound`. `resolve_sequence()` returns the graph used by both Flow and
TEValidator; invalid or ambiguous payloads fail before the director acquires input.
Existing episode resources and save files need no migration.

`CADCounterattackTemplate` exports two gates and six timeline names. It builds:

```text
defence -> evade -> counter -> land -> countered
       \-> hit_reaction -> hit       \-> recover -> defended
```

Published beat IDs are `defence`, `evade`, `hit_reaction`, `counter`, `land` and
`recover`. Configure the three terminal outcome IDs if different names are needed.
All gate options are copied and wired to the corresponding successful reaction;
timeout goes to its failure reaction. Grade overrides remain configurable, but
must choose `evade/hit_reaction` for defence or `land/recover` for the counter.
This prevents template-local cycles or silently skipped choreography. Use a plain
CADSequence for a different graph. `build()` returns null on invalid authoring;
`last_errors` and `validation_errors()` provide diagnostics without mutating gates.

A missed or partial counter can therefore finish `defended`, with the defence's
original result intact. Input handlers still know nothing about the compound.
The timelines own shots, root motion and paired `act()` cues. The directional lab
stage uses separate method tracks for simultaneous player/NPC/camera calls and
has tested root continuity at all template branch boundaries. Real skeletal pose
blends and physical contact remain an asset-level acceptance task.

### Ordered and alternating inputs

`CADInteractionSpec.Family.PATTERN` uses `pattern_steps` (1–64 action IDs;
repetitions allowed), one relative `pattern_deadlines` duration per step, and
`pattern_min_seconds` between opening/accepted input and the next accepted input.
Keep ordinary `actions` empty. Alternation is authored as e.g.
`[cad_a, cad_b, cad_a, cad_b]`; it needs no special evaluator. Deadlines begin at
gate opening or the previous accepted step. Both the per-step and overall gate
deadlines win exact ties; simultaneous samples cannot advance multiple steps.

`pattern_error` is IGNORE, RESET or FAIL for wrong/early edges. RESET discards
all accepted steps and starts the first deadline at that edge, without extending
the gate window. FAIL returns `miss`; existing `routes[miss]` supplies branching.
Timeout retains bounded progress. Only fresh pressed edges advance; held input,
keyboard repeat and source-mismatched releases use the shared router policies.
Pause discards incomplete patterns; resume starts a fresh first-step deadline
within the remaining active gate budget. Timing assistance widens each relative
deadline, while the minimum interval remains explicit. The prompt displays the
ordered, remapped controls and completed steps; `runner.completed_steps()` exposes
the read-only count for custom UI.

### Combo and attack/defence chains

`CADChainTemplate` compiles `gates`, `input_timelines`, `action_timelines` and
`recovery_timelines` (equally sized arrays, 1–32 components) into a `CADSequence`.
Each component enters `input_N`, successful input plays `action_N`, and failure
plays `recover_N` then exits with `interrupted_outcome`. A successful action
finishes its authored timeline before opening the next input. All components
completed yields `completed_outcome`. Results remain per-component legacy strings
plus encounter-local typed detail. Gates are deep copied for each build.

Grade overrides may choose only that component's `action_N` or `recover_N`; this
prevents loops and skipped paired reactions. Arbitrary graphs remain available
through `CADSequence`. `CADThreePunchTemplate` uses the same compiler and requires
exactly three gates and three distinct action timelines. It does not infer contact
frames or create animations. Author both actor cues, positions and camera cuts in
each timeline. Blend duration defaults to 0.08 seconds. Supply explicit recovery
timelines with compatible entry poses, including after the final input.

`CADInteractionHandler.resume_input(elapsed)` is an optional extension hook called
when active-time input resumes, after `reset_input()` on suspension. It must not
resolve an interaction or advance Story; runners still own completion and routing.

### Targets, tracking and prop sockets

`CADInteractionSpec.Family.TARGET` maps `target_options` (stage target ID → gate
option ID). A stage exports `target_registry: CADTargetRegistry`; its `targets`
map IDs to Node3D paths relative to the registry. Optional `labels` and `requires`
(a flag or `!flag`) control presentation and eligibility. Missing bindings are
validation errors. Hidden, behind-camera, off-screen and ineligible targets are
excluded from snapshots. There is no occlusion raycast: author eligibility or
hide blocked targets where that distinction matters.

The director supplies an injectable `target_snapshot` Callable and `target_extent`
to the runner. Snapshots contain only `{id, label, position}`; coordinates and
`target_radius` use viewport-height units. The runner never retains world nodes.
Focus uses nearest distance then stable ID; cycling follows sorted eligible IDs.
Direction actions aim the reticle through the existing analogue/digital router.
`target_confirm_action`, `target_next_action`, and `target_previous_action` are
remappable and distinct. Acquisition starts at the first eligible target. Zero
`target_lock_seconds` confirms instantly; a positive value requires held confirm
and continuous focus. Focus changes, release and pause clear progress and require
fresh confirm. A gap over 0.1 active seconds earns no unobserved tracking credit.
The gate deadline still limits retries. A missing target produces no selection,
then the authored timeout/recovery route. `runner.target_view()` provides an
isolated presentation snapshot; `CADTargetOverlay` draws passive labels/reticle
below the pause layer. It does not read input or grant Story state.

`CADResult.target_id` identifies the selected target independently of its option.
`CADGrabTemplate` compiles one Target gate through the shared chain compiler. Its
successful action timeline calls:

```gdscript
attach_selected_prop(&"input_1", &"Player", ^"Rig/HandSocket")
detach_selected_prop(&"input_1")
```

These stage markers read the runner's result. Direct `attach_prop(target_id,
role, socket_path)` / `detach_prop(target_id)` are also available. The socket is
an authored Node3D or BoneAttachment3D below the bound actor. Attach retains the
current contact offset; it never snaps to an inferred hand pose. Place contact
and prop/actor keys explicitly before this marker. Stage validation checks result
beat references and, when actors are bound, socket existence before acquisition.
The episode-only validator cannot verify an unavailable real rig's sockets.

`CADPropAttachments` follows the socket with a RemoteTransform3D while the prop
keeps its scene parent, so actor deletion does not destroy the prop. Rigid props
freeze during ownership and regain their original freeze setting on detach.
Cancellation/error restores the original acquisition transform, even after an
authored drop; successful release preserves authored final placement and removes
all remaining socket ownership. Stage unload also cleans up. These helpers return
`false` on invalid/missing prop/socket arguments. They do not apply impulses,
manage a physics inventory, or persist mid-contact poses.
