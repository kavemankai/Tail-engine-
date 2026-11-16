# Authoring an episode

An episode is a folder of data. `content/episode_0` is the working example; copy it to start a new one.

```
episode.tres      the step graph
manifest.tres     story variables and major choices
cast.tres         characters
dialogue/*.dialogue
locations/*.tscn
encounters/<name>/stage.tscn + encounter.tres
```

Point `content/main.gd` at your `episode.tres`. Run `tests/validate.tscn` after every change; it reports missing names before you have to play to find them.

## The step graph

`episode.tres` is a `TEEpisode`: a list of `TEStep` resources and an entry step. Only the graph decides what happens next. Each step runs, ends with a named exit, and the step's `exits` list maps that name to the next step.

| Kind | What runs | What it ends with |
|---|---|---|
| Explore | A hub in the location. The player walks and uses hotspots. | The `exit` of the hotspot that ended it. |
| Dialogue | One cue from a dialogue file. | `end`, or the name passed to `exit("...")` in the file. |
| Encounter | A `CADSequence` on a stage in the location. | The sequence's outcome. |
| Card | A title card, or the recap of choices. | `end`. |

An exit (`TEExit`) has `on` (a name, or `*` for any), an optional `when` condition, and `next` (a step id or `END`). The first match wins, so put conditional exits before the catch-all.

Other step fields:

- `location`: a scene path. Leave empty to stay where you are. Changing it fades out and in.
- `cast`: character id to mark name. Actors are created on first use and stay in the location. An empty mark leaves the actor where it stands.
- `checkpoint`: saves when the step starts. The player can resume or rewind to it. `title` is the name shown in the menu.

A non-interactive cutscene is an Encounter whose sequence has no gates.

## Story state

`manifest.tres` declares every variable with its starting value, and every major choice with one recap sentence per option. Using an undeclared name is an error at validation and at run time.

From a dialogue file:

```
do Story.put("bartender_talked", true)
do Story.remember("bartender_friendly", true, "The bartender will remember that.")
do Story.choose("stranger", "insult")
if Story.flag("stool_noticed")
if Story.outcome("bar_fight") == "won"
```

`remember` with a third argument raises the notice banner. `choose` logs a choice for the recap card. `Story.outcome(step_id)` is how any step ended. `Story.result(step_id, beat_id)` is what the player did at one gate in an encounter: an option id or `timeout`.

## Conditions

One expression language is used for step exits and hotspots. Variables are available by name and `Story` methods can be called:

```
bartender_friendly and not insulted_stranger
outcome('bar_fight') == 'won'
```

Action sequences use plain flag names instead (see below).

## Dialogue files

Standard Dialogue Manager syntax, with these tags:

| Tag | On | Effect |
|---|---|---|
| `[#timed=6]` | the line before responses | The choice has a 6 second timer. |
| `[#silence]` | a response | Taken when the timer runs out. Without one, the first response is taken. |
| `[#shot=name]` | a line | Cuts to that camera in the location. |
| `[#opt=name]` | a response | A stable name for tests and tools. |
| `[ID:e0_001]` | a line | The line's id. Voice files are named after it. |

Speaker names are character ids from the cast. To end a step with a named exit, call `do exit("paid")` before the conversation ends.

A conversation offers up to four responses, on `te_choice_1` to `te_choice_4`.

## Locations

A location scene has a `TELocation` root. The engine finds everything by name:

| Path | Node | Used for |
|---|---|---|
| `Marks/<name>` | `Marker3D` | Where cast members stand. Rotation counts. |
| `Shots/<name>` | `Camera3D` | Dialogue and wide shots. |
| `Hubs/<name>` | `TEHub` | A walk-around area with `TEHotspot` children. |
| `Zones/<name>` | `TECameraZone` with a `Camera3D` child | Optional fixed camera while the player is near. |
| `<name>` | `CADStage` | An encounter stage, instanced as a direct child. |

Floors and walls need collision or the player falls through.

A `TEHotspot` has a verb `label`, a `radius`, and does one or both of: run a `cue` from the hub's dialogue file, and end the step with `exit`. `when` hides it behind a condition. `once` retires it after one use.

## Encounters

Built with the action layer; [INTEGRATION.md](INTEGRATION.md) is the full reference. What matters when it runs inside an episode:

- The step's `stage` names the `CADStage` node in the location, and `roles` maps stage slots to character ids. Those actors follow their slots for the encounter and stay where it leaves them.
- Sequence flags are the story variables. `CADOption.requires = "stool_noticed"` offers an option only if the player looked at the stool earlier. `CADBranch.requires = "insulted_stranger"` sends an ungated beat down a different path. Prefix a name with `!` to require it unset.
- Each gate's result and the outcome are written to `Story` when it ends.
- Start the first timeline with actors where the previous step's marks put them, or they will jump.

## Testing a route

Choose **Interaction lab** on the title menu, or open `content/qte_lab/lab.tscn`.
The reaction, hold, timed-release, chord, parry and restraint `.tres` resources use
the existing bar stage's windup, dodge, hit and back-off timelines. Parry grades
have separately named perfect, success, partial and failure routes. `episode.tres`
binds the normal cast through Flow. No
QTE behaviour lives in the lab script. It disables saves and leaves Episode 0's
original encounters and narrative branches intact. Back to Last Call restores
the normal save slot. See the v2 section in
[INTEGRATION.md](INTEGRATION.md) for spec fields and clock/input policies.

`tests/autoplay.gd` plays an episode from a policy: which `opt` names to pick, which hotspots to visit, which button to press at which beat. `tests/test_flow.gd` shows four routes with assertions on the steps taken and the story state at the end. Add one per ending you care about.

In a debug build, F3 opens a panel with the current step and variables, and buttons to force any exit or jump to any step.


## Counterattacks and directional variants

Set an encounter step's `compound` to a `CADCounterattackTemplate` resource instead
of setting `sequence`. Author its defence/counter gates and six timeline names;
Flow compiles a fresh ordinary CADSequence when entering the encounter. The
validator checks both the graph and the stage. See
`content/qte_lab/direction/counter.template.tres` and its episode for the complete
example. Missing the counter follows recovery and preserves the defence result.

Direction specs use four remappable actions, a sector, thresholds and flick/hold/
selection policy. Use named option IDs in `direction_options`, not display text.
Input-relative examples use the same camera geography for both shots; camera-
relative specs freeze a planar frame when opening the gate. See INTEGRATION.md
for sector IDs, settling/rearm semantics, and template grade-route constraints.

`content/episode_0/encounters/*/directional.tres` are opt-in variants. The bar uses
true directional dodge; the alley's high/low fork uses Direction selection. Their
original graphs, flag-conditioned stool/bartender consequences and outcomes are
preserved. `content/qte_lab/direction/episode_0_directional.tres` exercises them
through the full story graph without changing the default episode. Run validation
and the `compounds` suite after editing these resources.

### Patterns and multi-action compounds

The lab adds alternating and ordered Pattern resources plus `pattern/combo.tres`
and `pattern/chain.tres`. Open their `_episode.tres` entries from the Interaction
lab. Use `pattern_steps`, relative `pattern_deadlines`, `pattern_min_seconds`, and
`pattern_error` to author input sequences. Do not put repeated steps in `actions`.
A reset retries inside the original gate budget; it cannot extend that budget.

Use `TEStep.compound` with `CADThreePunchTemplate` for three separately triggered
strikes, or `CADChainTemplate` for a mixture of attack and defence gates. Assign
one input, paired action and recovery timeline per gate. Each accepted input
plays its action timeline once before the next gate; a missed input plays the
matching recovery. Leave gate option destinations empty for the compiler to wire.
The standard beat IDs are `input_1`, `action_1`, `recover_1`, etc.; grade routes can
only select that component's action or recovery. Use a plain sequence for other
graph shapes.

`python tools/build_pattern_examples.py` rebuilds the native examples and their
AnimationLibrary; it contains authoring data, never input evaluation. The three
punches cue distinct logical clips (`punch_jab`, `punch_cross`, `punch_hook`) and
paired `recoil_jab`, `recoil_cross`, `recoil_hook` NPC clips. Map these in your cast.
Run `qte_pattern chains` and the full verifier after edits. The fixture proves
three distinct skeletal poses and continuous timeline roots, not real humanoid
contact or production animation quality.

### Target and grab examples

`target/selection_episode.tres`, `tracking_episode.tres`, and `grab_episode.tres`
use the shared registry/evaluator and the standard Flow. Default controls: aim
with remappable WASD / left stick / D-pad, cycle with Space/A and K/B, confirm
with J/X. Moving targets require held confirm inside the reticle; cycling or
losing focus requires a new confirm. All prompts follow InputMap remapping.

Add a `CADTargetRegistry` to your stage, assign it to `target_registry`, and bind
stable IDs to visible Node3Ds. In the interaction, map those IDs to offered gate
options with `target_options`. Registry `requires` reads narrative flags. The lab
manifest begins with `saw_bottle` set so its grab is available; clearing it makes
the bottle ineligible and demonstrates the no-target recovery route. No widget
sets the flag or the selected result. Occlusion needs authored eligibility.

For a grab, use `CADGrabTemplate` with one Target gate and input/action/recovery
timelines. The action timeline calls `attach_selected_prop` at contact and
`detach_selected_prop` at release, referencing `input_1`. Keep props in the stage
and provide a Node3D/BoneAttachment3D socket below the bound character. The lab
uses a greybox hand marker; automated tests also exercise a real BoneAttachment3D
on the minimal skeletal adapter. Match actor/prop contact before attaching to
preserve the authored offset without a visible snap. Validate the actual humanoid
kit separately. Run `qte_target` and the full verifier after changing bindings.
`python tools/build_target_examples.py` regenerates native resources/timelines.

### Pressure and grapple examples

The lab's Opposed pressure entry demonstrates success, partial and loss reactions.
Hold J/X or the alternate K/B control; force is sustained, with no mash bonus.
Release to yield against authored resistance. `pressure_start`, `pressure_gain`,
`pressure_resistance`, `pressure_partial` and an optional opposition Curve control
the contest. Keep a partial route explicit if it should differ from timeout.

Grapple escape uses a `CADGrappleTemplate`: move left, sustain pressure, then press
and release J/X at the next opening. Release controls between prompts. Every step
has independent results and an authored recovery. The alternate pressure control
is available from the start; it needs no rapid alternation. The examples dispatch
logical `grapple_struggle`, `grapple_escape`, `grapple_stagger` and
`grapple_release` clips through TEActor. These are adapter/greybox demonstrations;
real paired humanoid contact remains an acceptance gate. Rebuild native resources
with `python tools/build_pressure_examples.py`; run `qte_pressure` and verification.

### Cinematic decisions and adaptive follow-through

The lab's **Last chance — cinematic intent** episode combines a half-speed parry,
a quarter-speed action conversation, semantic choices and preauthored follow-through.
A perfect defence earns two momentum; restraining with sufficient momentum, a
ready player and an observed available prop selects the strong timeline. Escape
selects a separate route. Mistakes and missing props take compatible recovery.
The lab manifest supplies prior observation flags; production episodes should earn
these in exploration/dialogue. All choreography is native AnimationPlayer data.

Use `playback_scale` per beat and provide the three TEActor playback hooks for
AnimationTree rigs (see ASSET_SWAP). Input seconds remain real active seconds.
Set `option_intents` and per-grade `momentum_changes` in interaction specs. Declare
role/status and prop IDs on the sequence before using `actor_changes`,
`prop_changes`, or `CADContextPredicate` on a branch. Keep a compatible fallback;
the engine selects authored clips and does not synthesize contact alignment.

Author short `CADBark` resources on the stage and call `bark(id)` from timelines.
Use Choice gates for replies; let the action director own input until the encounter
ends. Afterwards regular dialogue can read `Story.intent("lab")`, as the example's
`aftermath.dialogue` demonstrates. Completed grades, targets, momentum and intent
are available through Story's history readers without changing old option strings.
Place checkpoints at safe boundaries; resume never reconstructs a live grapple.

Regenerate the example with `python tools/build_cinematic_examples.py`. Run
`qte_cinematic action_dialogue qte_narrative`, then the full verifier. Tests exercise
actual skeletal TimeScale playback, voice ownership/pause, all adaptive routes,
Dialogue Manager handoff, JSON save/resume, rewind and cancellation during dialogue.
The lab uses greyboxes and no production voice/contact kit.
