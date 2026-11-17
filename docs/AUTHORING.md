# Authoring an episode

An episode is a folder of data. `python tools/new_project.py ../my_game "Title"` creates a new game with a one-scene starter episode; `examples/last_call/episode_0` is the fuller working example.

```
episode.tres      the step graph
manifest.tres     story variables and major choices
cast.tres         characters
dialogue/*.dialogue
locations/*.tscn
encounters/<name>/stage.tscn + encounter.tres
```

Set `episode` (or `season`) on your `TETitleMenu` scene to your `episode.tres`. Run `tests/validate.tscn` after every change; it reports missing names before you have to play to find them.

## The step graph

`episode.tres` is a `TEEpisode`: a list of `TEStep` resources and an entry step. Only the graph decides what happens next. Each step runs, ends with a named exit, and the step's `exits` list maps that name to the next step.

| Kind | What runs | What it ends with |
|---|---|---|
| Explore | A hub in the location. The player walks and uses hotspots. | The `exit` of the hotspot that ended it. |
| Dialogue | One cue from a dialogue file. | `end`, or the name passed to `exit("...")` in the file. |
| Encounter | A `CADSequence` on a stage in the location. | The sequence's outcome. |
| Card | A title card, the recap of choices, or rolling credits. | `end`. |
| Cutscene | A list of camera cues with no input. See [Camera and cutscenes](#camera-and-cutscenes). | `end`. |

An exit (`TEExit`) has `on` (a name, or `*` for any), an optional `when` condition, and `next` (a step id or `END`). The first match wins, so put conditional exits before the catch-all.

Other step fields:

- `location`: a scene path. Leave empty to stay where you are. Changing it fades out and in.
- `cast`: character id to mark name. Actors are created on first use and stay in the location. An empty mark leaves the actor where it stands.
- `checkpoint`: saves when the step starts. The player can resume or rewind to it. `title` is the name shown in the menu.

For a non-interactive scene, use a Cutscene step for camera cues and captions, or an Encounter whose sequence has no gates when it needs choreographed stage timelines.

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

Choose **Interaction lab** on the title menu, or open `examples/last_call/qte_lab/lab.tscn`.
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
`examples/last_call/qte_lab/direction/counter.template.tres` and its episode for the complete
example. Missing the counter follows recovery and preserves the defence result.

Direction specs use four remappable actions, a sector, thresholds and flick/hold/
selection policy. Use named option IDs in `direction_options`, not display text.
Input-relative examples use the same camera geography for both shots; camera-
relative specs freeze a planar frame when opening the gate. See INTEGRATION.md
for sector IDs, settling/rearm semantics, and template grade-route constraints.

`examples/last_call/episode_0/encounters/*/directional.tres` are opt-in variants. The bar uses
true directional dodge; the alley's high/low fork uses Direction selection. Their
original graphs, flag-conditioned stool/bartender consequences and outcomes are
preserved. `examples/last_call/qte_lab/direction/episode_0_directional.tres` exercises them
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

### Audit and diagnose a new encounter

1. Create a sequence/compound and put it in a `TEEpisode` with its cast and stage.
2. Run `godot --headless --path . res://tools/authoring.tscn -- res://path/episode.tres`.
   Fix reported errors and review reachability/possible ungated-cycle warnings.
   The JSON report lists beat/gate counts and handler families. Intentional gated
   retries remain allowed; warnings do not infer the effects of animation methods.
3. In a debug build, use F3 to inspect the active beat, momentum/intent, actor/prop
   context, time/progress and controller owner. Export the bounded trace to
   `user://cad_trace.json`; indices and dropped counts identify buffer truncation.
4. Run the full verifier, then perform the Windows/controller and production-rig
   acceptance checks. Numeric root continuity and synthetic inputs remain separate
   from visual contact/retargeting, audible mix and physical-driver verification.

`python tools/verify.py` now audits all lab episodes after regression/episode
validation. Engine errors and ObjectDB leaks are still failures. The test harness
also rejects a non-instantiable suite immediately instead of waiting for the outer
timeout. New stories can reuse the examples and templates without changing QTE
runtime; live simultaneous Dialogue Manager balloons remain a deferred extension.

## Seasons

A season (`TESeason`) is an ordered list of episodes plus the variables that carry forward:

```
season.tres
  episodes         [episode_1.tres, episode_2.tres, ...]
  carry_variables  [&"trusted", ...]
```

Point the title menu at it (`season = ...` on a `TETitleMenu`) or call `Flow.start_season(season)`. When an episode finishes, `Flow.next_episode()` starts the next one (the menu shows **Next episode**).

- Variables in `carry_variables` copy into the next episode if its manifest declares them too.
- Major choices of earlier episodes are readable with `Story.prior("episode_1", "gift")`, which returns the option id or an empty string. Use it in dialogue conditions: `if Story.prior("episode_1", "gift") == "keep"`.
- The next episode's recap starts fresh.
- Saves record the season, so Continue and rewind return to the right episode with carried state intact. The title menu cycles `slot_count` save slots.

## Cards, history and waiting for the player

A Card step has three forms, set by `card`:

- **Title** (`0`): `heading` and `body` for about three seconds, or until the player advances.
- **Recap** (`1`): the recap sentence of every major choice made, from the manifest. It stays until the player advances.
- **Credits** (`2`): `heading` and `body` roll up the screen. One name or role per line; the player can skip.

Every spoken line and chosen response is kept for the session and shown under **History** in the pause menu. `Screen.history()` returns the same list.

Subtitle text is rich text: `[b]`, `[i]` and `[color=...]` work in dialogue lines.

Players can turn off **Advance lines automatically**; each line then waits for the advance button. Do not rely on a line disappearing by itself to time a scene: use a Cutscene or Encounter step for timing.

Locations load in the background. A loading indicator appears if a load takes longer than a moment. With a season, the title menu offers **Episodes** once the player has reached a second episode.

## Translating a game

Write the game in one language; that text is the key for every other language.

1. Export a template of everything outside dialogue files:
   `godot --headless --path . res://addons/tale_engine/editor/export_strings_cli.tscn -- strings.pot res://game/season.tres`
   Pass a season or any number of episodes. The template holds the engine's own interface text plus episode titles, card headings and bodies, cutscene captions, hotspot verbs, recap sentences, character names, action prompt labels and barks.
2. For dialogue lines, give each line an `[ID:...]` and add the `.dialogue` files under Project Settings > Localization > POT Generation; Godot's **Generate POT** writes them.
3. Translate both templates into `.po` files and add them under Project Settings > Localization > Translations.

Once a translation is loaded, Settings shows a **Language** option. It lists the game's own language (`internationalization/locale/fallback`, `en` by default) and every loaded translation; "System" follows the player's machine. The choice is saved and menus redraw at once.

In your own scripts, pass text through `tr()` before showing it; `Screen.notice`, `Screen.caption` and `Screen.card` already do. Button letters and key names are never translated.

Voice files are not yet switched by language.

## When a step breaks

A step that cannot run (missing stage, hub or sequence) ends with the exit `error`; an encounter that is cancelled ends with `cancelled`. `*` does not match these two names. If nothing routes them, or an exit points at a step that does not exist, the episode stops: the player sees a short message and returns to the menu with their last checkpoint intact, and `Flow.episode_failed(reason)` is emitted instead of `episode_finished`. Add an exit with `on = "error"` only where the story has a real fallback.

Faults are reported through `TEFault.report`. Set `TEFault.handler` to a callable to log or upload them.

Using a variable or choice option that the manifest does not declare is a fault, and the value is not stored.

## Patching a released episode

Saves are repaired to match the episode as it is now, so a patch does not cost players their progress:

- A checkpoint whose step was removed is dropped; the newest surviving checkpoint is used. If none survive, the episode restarts with the story state intact.
- A removed variable or choice option is dropped. A variable whose type changed goes back to its default.
- If you rename a checkpoint step, add `old_id -> new_id` to `TEEpisode.renamed_steps`. If you rename a variable, add `old_name -> new_name` to `TEStoryManifest.renamed_variables`. Saves follow the rename.

Each write keeps the previous save as `slot_N.json.bak`; a damaged save falls back to it. `TESave.last_status` after a read says whether the slot was empty, fine, recovered or unreadable, and `TESave.info(slot)` returns the checkpoint title, save time and playtime for a slot list.

Finishing an episode of a season moves the save to the start of the next one, so Continue after closing the game starts the next episode with carried state.

## Camera and cutscenes

Locations supply cameras as `Shots/<name>`. Use `TEShot` instead of a plain `Camera3D` to author a slow move: `drift` (local-space translation), `fov_drift` and `drift_time` play while the shot is active and reset when another takes over.

In dialogue, tags on a line direct the camera:

```
friend: We need to go. [#shot=close, #blend=0.6, #shake=0.05]
```

- `shot` cuts to that shot.
- `blend` (seconds) flies the camera there from the current view instead of cutting.
- `shake` is an amplitude in metres that fades out over about half a second.

A **Cutscene** step (`kind = 4`) plays a list of `TEShotCue` resources with no input: each cue has a `shot`, `blend`, `hold`, optional `shake`, a `speaker` (marks that actor as talking), a `caption`, and `clips` (character id to logical clip, played as the cue starts). It ends with the exit `end`. The validator checks that every cue's shot, speaker and character exist.

From code, `Flow.camera` (`TECamera`) offers `cut_to`, `blend_to` and `shake`.

## Editor tooling

The Tale Engine plugin (enabled in `project.godot`) adds a **Tale Engine** panel at the bottom of the editor. Select an `episode.tres` and the panel shows its step graph: one node per step, one output per exit, and an END node. Clicking a node selects that step in the inspector. **Add step** appends a step of the chosen kind and saves the episode. **Validate** runs the same validator as `tests/validate.tscn` in a headless game process and lists the problems.

The same check from a terminal: `godot --headless --path . res://addons/tale_engine/editor/validate_cli.tscn -- res://path/to/episode.tres`.

## Voice and lip-sync

Give a character a `voice_dir` and put recordings there named after the dialogue line id: `e0_007.ogg` (or `.wav`, `.mp3`) for `[ID:e0_007]`. Missing files are fine; the line just plays on its reading timer.

- **Recording script:** `godot --headless --path . res://addons/tale_engine/editor/export_voice_cli.tscn -- res://path/episode.tres script.csv` writes one row per line (id, speaker, text, recorded yes/no, expected file).
- **Coverage:** `TEVoice.coverage(episode)` returns `[recorded, total]`; `tests/validate.tscn` prints it.
- **Lip-sync:** voice plays on a `Voice` audio bus. While a line plays, its speaker's `set_mouth_open(0..1)` is called every frame with the smoothed loudness. The default `TEActor` drives a mouth blend shape named `jawOpen`, `mouthOpen`, `mouth_open`, `viseme_aa` or similar on any mesh under the actor. Override `set_mouth_open` for jaw bones, texture swaps or sprite mouths.
