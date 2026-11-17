# Mechanics to test

Every mechanic a slice episode should exercise before the engine is called ready. Tick **Slice** when your episode uses the mechanic and it behaves correctly in a real playthrough (not only in the automated suites).

**Status** says whether you can author it today:

- **Now** — works as described.
- **Now, changes in P*n*** — works, but phase *n* of the plan changes how it behaves or is authored. Usable now; re-test after that phase.
- **New in P*n*** — does not exist yet. Leave room for it; it is added in phase *n*.
- **Now (PR #*n*)** — done, and available once that pull request is merged.

Phases: P2 saves and failure handling, P3 UI/input/settings, P4 localisation, P5 audio, P6 direction, P7 exploration, P8 editor, P9 platform. This file is updated at the end of every phase.

Authoring reference: [AUTHORING.md](AUTHORING.md) for episodes, [INTEGRATION.md](INTEGRATION.md) for action sequences. Working examples: `examples/last_call/episode_0` and the Interaction lab (`examples/last_call/qte_lab`).

## 1. Episode flow

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 1.1 | Title card step | `TEStep.kind = CARD`, `card = TITLE`, `heading`, `body` | Now | [ ] |
| 1.2 | Recap card step | `kind = CARD`, `card = RECAP`; text from manifest recap sentences | Now, changes in P3 (becomes a choices screen) | [ ] |
| 1.3 | Dialogue step | `kind = DIALOGUE`, `dialogue`, `cue`, optional `shot` | Now | [ ] |
| 1.4 | Explore step | `kind = EXPLORE`, `hub` names `Hubs/<name>` | Now, changes in P7 | [ ] |
| 1.5 | Encounter step with a sequence | `kind = ENCOUNTER`, `sequence`, `stage`, `roles` | Now | [ ] |
| 1.6 | Encounter step with a compound template | `compound` instead of `sequence` | Now | [ ] |
| 1.7 | Cutscene step (shot cues) | `kind = CUTSCENE`, `cues: Array[TEShotCue]` | Now, changes in P6 (voice, sfx, skip) | [ ] |
| 1.8 | Timeline step (authored AnimationPlayer cutscene) | new step kind | New in P6 | [ ] |
| 1.9 | Named exits | `TEExit.on` matches the step's exit name; `next` is a step id or `END` | Now | [ ] |
| 1.10 | Conditional exit | `TEExit.when = "flag and not other"`; conditional exits listed before the catch-all | Now | [ ] |
| 1.11 | Wildcard exit | `on = "*"` | Now (PR #12: `error`/`cancelled` no longer fall through it) | [ ] |
| 1.12 | Location change with fade | `TEStep.location` set to a different scene | Now, changes in P3 (loading screen) | [ ] |
| 1.13 | Staying in the current location | `location` left empty | Now | [ ] |
| 1.14 | Cast placement on marks | `TEStep.cast = {character_id: mark_name}` | Now | [ ] |
| 1.15 | Actor left where it stands | empty mark name in `cast` | Now | [ ] |
| 1.16 | Checkpoint | `TEStep.checkpoint = true`, `title` shown in the menu | Now | [ ] |
| 1.17 | Episode end | exit with `next = END` | Now | [ ] |
| 1.18 | Runtime fault shows an error, not an ending | missing step or unrouted exit; `Flow.episode_failed` | Now (PR #12) | [ ] |

## 2. Seasons

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 2.1 | Season of several episodes | `TESeason.episodes`; `TETitleMenu.season` | Now | [ ] |
| 2.2 | Next episode from the menu | automatic when the season has another episode | Now | [ ] |
| 2.3 | Carried variables | `TESeason.carry_variables`, declared in both manifests | Now | [ ] |
| 2.4 | Reading an earlier episode's choice | `Story.prior("episode_1", "choice_id")` in dialogue or a condition | Now | [ ] |
| 2.5 | Next episode still offered after quitting and relaunching | none (engine behaviour) | Now (PR #12) | [ ] |
| 2.6 | Episode select | title menu | New in P3 | [ ] |

## 3. Story state

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 3.1 | Declared variables with defaults | `manifest.tres` variables | Now | [ ] |
| 3.2 | Set a variable | `do Story.put("name", value)` | Now (PR #12: undeclared names rejected) | [ ] |
| 3.3 | Add to a number | `do Story.add("name", 1)` | Now | [ ] |
| 3.4 | Remember with a notice | `do Story.remember("name", true, "They will remember that.")` | Now, changes in P3 (animated notice) | [ ] |
| 3.5 | Major choice for the recap | `do Story.choose("choice_id", "option_id")`, declared in the manifest | Now | [ ] |
| 3.6 | Read a flag or value in dialogue | `if Story.flag("name")`, `Story.value("name")` | Now | [ ] |
| 3.7 | Read how a step ended | `Story.outcome("step_id")` | Now | [ ] |
| 3.8 | Read one gate's result | `Story.result("step_id", "beat_id")` | Now | [ ] |
| 3.9 | Read action intent afterwards | `Story.intent("step_id")` | Now | [ ] |
| 3.10 | Inventory item gained, held, used | manifest-declared items | New in P7 | [ ] |

## 4. Dialogue

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 4.1 | Spoken line with a cast speaker | `character_id: text` | Now | [ ] |
| 4.2 | Untimed choice, 2 to 4 responses | Dialogue Manager responses | Now, changes in P3 (focus navigation) | [ ] |
| 4.3 | Timed choice | `[#timed=6]` on the line before the responses | Now | [ ] |
| 4.4 | Silence as an answer | `[#silence]` on one response | Now | [ ] |
| 4.5 | Timer with no silence option | timed line, no `#silence`; first response is taken | Now | [ ] |
| 4.6 | Stable option names | `[#opt=name]` on a response | Now | [ ] |
| 4.7 | Conditional response or line | `if Story.flag(...)` | Now | [ ] |
| 4.8 | Ending a step from dialogue | `do exit("name")` | Now | [ ] |
| 4.9 | Camera cut on a line | `[#shot=name]` | Now | [ ] |
| 4.10 | Camera blend on a line | `[#shot=name, #blend=0.6]` | Now | [ ] |
| 4.11 | Camera shake on a line | `[#shake=0.05]` | Now | [ ] |
| 4.12 | Emotion on a line | `[#emote=name]` | New in P6 | [ ] |
| 4.13 | Gesture on a line | `[#gesture=name]` | New in P6 | [ ] |
| 4.14 | Look-at on a line | `[#look=character_or_mark]` | New in P6 | [ ] |
| 4.15 | Animation clip on a line | `[#clip=name]` | New in P6 | [ ] |
| 4.16 | Skip the current line | advance input | Now | [ ] |
| 4.17 | Auto-advance toggle and skip-seen | settings and input | New in P3 | [ ] |
| 4.18 | Backlog | pause menu or input | New in P3 | [ ] |
| 4.19 | Rich text in subtitles | BBCode in a line | New in P3 | [ ] |

## 5. Exploration

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 5.1 | Walking in a hub | `TEHub` under `Hubs/`, player from `TEEpisode.player` | Now, changes in P7 (camera-relative, walk/idle clips) | [ ] |
| 5.2 | Follow camera | `TEHub` default | Now, changes in P7 (smoothing, collision) | [ ] |
| 5.3 | Fixed camera zone | `TECameraZone` with a `Camera3D` child under `Zones/` | Now | [ ] |
| 5.4 | Hotspot that runs a conversation | `TEHotspot.cue` | Now | [ ] |
| 5.5 | Hotspot that ends the step | `TEHotspot.exit` | Now | [ ] |
| 5.6 | Hotspot that does both | `cue` and `exit` | Now | [ ] |
| 5.7 | Conditional hotspot | `TEHotspot.when` | Now | [ ] |
| 5.8 | One-use hotspot | `TEHotspot.once` | Now | [ ] |
| 5.9 | Hotspot highlight and facing check | none (engine behaviour) | New in P7 | [ ] |
| 5.10 | Examine view | hotspot option | New in P7 | [ ] |
| 5.11 | Hotspot that needs an item | `TEHotspot.requires_item` | New in P7 | [ ] |
| 5.12 | Something noticed in a hub changes a later fight | hotspot sets a flag; `CADOption.requires` reads it | Now | [ ] |

## 6. Action sequences

Interaction families are set on `CADGate.interaction` (`CADInteractionSpec`). Each has a lab example to copy.

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 6.1 | Legacy press / hold gate | `CADGate` with no `interaction` | Now | [ ] |
| 6.2 | Gesture: press | `family = GESTURE`, `gesture = PRESS` (lab: Reaction press) | Now | [ ] |
| 6.3 | Gesture: hold | `gesture = HOLD`, `hold_seconds` (lab: Hold) | Now | [ ] |
| 6.4 | Gesture: timed release | `gesture = TIMED_RELEASE` (lab: Timed release) | Now | [ ] |
| 6.5 | Gesture: chord | `gesture = CHORD`, 2 to 4 `actions` (lab: Simultaneous buttons) | Now | [ ] |
| 6.6 | Choice under time pressure | `family = CHOICE` | Now | [ ] |
| 6.7 | Graded timing / parry | `family = TIMING`, perfect/success/partial windows, `timing_marker` (lab: Graded parry) | Now | [ ] |
| 6.8 | Deliberate restraint | `family = PASSIVE` (lab: Deliberate restraint) | Now | [ ] |
| 6.9 | Direction: flick | `family = DIRECTION`, `direction_mode = FLICK` (lab: Directional dodge) | Now | [ ] |
| 6.10 | Direction: hold | `direction_mode = HOLD` (lab: Directional block) | Now | [ ] |
| 6.11 | Direction: select | `direction_mode = SELECT`, `direction_options` (lab: Directional choice) | Now | [ ] |
| 6.12 | Camera-relative direction | `direction_space = CAMERA` | Now | [ ] |
| 6.13 | Pattern: ordered | `family = PATTERN`, `pattern_steps` (lab: Ordered sequence) | Now | [ ] |
| 6.14 | Pattern: alternating | lab: Alternating buttons | Now | [ ] |
| 6.15 | Pattern error policy | `pattern_error = IGNORE / RESET / FAIL` | Now | [ ] |
| 6.16 | Target selection | `family = TARGET`, `CADTargetRegistry` (lab: Target selection) | Now | [ ] |
| 6.17 | Moving target lock | `target_lock_seconds > 0` (lab: Moving target lock) | Now | [ ] |
| 6.18 | Opposed pressure | `family = PRESSURE` (lab: Opposed pressure) | Now | [ ] |
| 6.19 | Counterattack template | `CADCounterattackTemplate` (lab: Dodge and counterattack) | Now | [ ] |
| 6.20 | Three-punch template | `CADThreePunchTemplate` (lab: Three-punch combo) | Now | [ ] |
| 6.21 | Chain template | `CADChainTemplate` (lab: Attack / defence chain) | Now | [ ] |
| 6.22 | Grab template with prop attach | `CADGrabTemplate`, `attach_selected_prop` (lab: Select and grab a prop) | Now | [ ] |
| 6.23 | Grapple template | `CADGrappleTemplate` (lab: Grapple escape) | Now | [ ] |
| 6.24 | Option gated by story state | `CADOption.requires = "flag"` or `"!flag"` | Now | [ ] |
| 6.25 | Branch gated by story state | `CADBranch.requires` | Now | [ ] |
| 6.26 | Grade routes | `CADInteractionSpec.routes` | Now | [ ] |
| 6.27 | Barks during action | `CADBark` on the stage, `bark(id)` from a timeline | Now | [ ] |
| 6.28 | Slow motion | `playback_scale` per beat | Now | [ ] |
| 6.29 | Momentum and intent | `momentum_changes`, `option_intents` (lab: Last chance) | Now | [ ] |
| 6.30 | Adaptive follow-through | `CADContextPredicate` on a branch | Now | [ ] |
| 6.31 | Non-interactive action cutscene | sequence with no gates | Now | [ ] |
| 6.32 | Missing a prompt fails forward | timeout route to a recovery beat | Now | [ ] |
| 6.33 | Longer windows assist | Settings: extended action prompts | Now | [ ] |
| 6.34 | Auto-complete and hold-toggle assists | Settings | New in P6 | [ ] |
| 6.35 | Controller unplugged mid-prompt pauses | none (engine behaviour) | Now (PR #12) | [ ] |

## 7. Camera and performance

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 7.1 | Named shot | `Camera3D` under `Shots/` | Now | [ ] |
| 7.2 | Drifting shot | `TEShot` with `drift`, `fov_drift`, `drift_time` | Now | [ ] |
| 7.3 | Cutscene cue: cut, blend, hold, shake | `TEShotCue` fields | Now | [ ] |
| 7.4 | Cutscene cue: caption and speaker | `TEShotCue.caption`, `speaker` | Now | [ ] |
| 7.5 | Cutscene cue: character clips | `TEShotCue.clips` | Now | [ ] |
| 7.6 | Cutscene cue: voice line and sound | new cue fields | New in P6 | [ ] |
| 7.7 | Skipping a cutscene | hold input | New in P6 | [ ] |
| 7.8 | Own character rig | scene extending `TEActor`, `TECharacter.actor_scene` and `clips` map | Now | [ ] |
| 7.9 | Lip movement from voice | `set_mouth_open` on the actor; blend shape named `jawOpen` or similar | Now, changes in P6 (jaw-bone fallback) | [ ] |

## 8. Audio

| # | Mechanic | How to author | Status | Slice |
|---|---|---|---|---|
| 8.1 | Voiced line | `TECharacter.voice_dir`, file named after `[ID:...]` | Now | [ ] |
| 8.2 | Unvoiced line on a reading timer | no file present | Now | [ ] |
| 8.3 | Recording script export | `export_voice_cli.tscn` | Now | [ ] |
| 8.4 | Music | `do Audio.music(load("res://path.ogg"))` from dialogue | Now, changes in P5 (per-step field, restored on resume) | [ ] |
| 8.5 | Ambience per location or step | step field | New in P5 | [ ] |
| 8.6 | Sound effect | `do Audio.effect(load("res://path.wav"))` | Now, changes in P5 (SFX bus, positional) | [ ] |
| 8.7 | Separate Music / SFX / Voice volume | Settings | New in P5 (buses) and P3 (sliders) | [ ] |

## 9. Saving

| # | Mechanic | How to test | Status | Slice |
|---|---|---|---|---|
| 9.1 | Continue | quit at any point after a checkpoint, relaunch, Continue | Now | [ ] |
| 9.2 | Rewind to an earlier checkpoint | title menu | Now (PR #12: asks first) | [ ] |
| 9.3 | Several save slots | title menu slot button | Now, changes in P3 (slot screen with details) | [ ] |
| 9.4 | New game over an existing save asks first | title menu | Now (PR #12) | [ ] |
| 9.5 | Save survives a content patch | rename a step or variable (add it to `renamed_steps` / `renamed_variables`), then Continue | Now (PR #12) | [ ] |
| 9.6 | Damaged save is reported, backup used | corrupt the file in `user://saves` | Now (PR #12) | [ ] |
| 9.7 | Story state restored exactly | make choices, Continue, check later branches | Now | [ ] |

## 10. Menus, settings and input

| # | Mechanic | How to test | Status | Slice |
|---|---|---|---|---|
| 10.1 | Title menu | `TETitleMenu` scene with `episode` or `season` | Now, changes in P3 (themed scene) | [ ] |
| 10.2 | Pause and resume | Escape / Start | Now | [ ] |
| 10.3 | Pause on focus loss | alt-tab | Now | [ ] |
| 10.4 | Subtitle size | Settings | Now | [ ] |
| 10.5 | Reading time | Settings | Now | [ ] |
| 10.6 | Untimed choices | Settings | Now | [ ] |
| 10.7 | Master volume | Settings | Now | [ ] |
| 10.8 | Window mode, resolution scale, vsync | Settings | New in P3 | [ ] |
| 10.9 | Subtitles on/off and background | Settings | New in P3 | [ ] |
| 10.10 | Language | Settings | New in P3 / P4 | [ ] |
| 10.11 | Keyboard and controller rebinding | Settings | New in P3 | [ ] |
| 10.12 | Prompts follow the last-used device | switch between keyboard and pad | Now, changes in P3 (icon glyphs, PlayStation and Steam Deck sets) | [ ] |
| 10.13 | Whole game playable on a controller alone | play without touching the keyboard | Now, changes in P3 | [ ] |
| 10.14 | Own UI look | swap the theme | New in P3 | [ ] |
| 10.15 | End-of-episode choices screen | automatic at episode end | New in P3 | [ ] |
| 10.16 | Credits | card or step | New in P3 | [ ] |
| 10.17 | Loading screen between locations | automatic | New in P3 | [ ] |
| 10.18 | Translated text everywhere | pseudo-locale run | New in P4 | [ ] |

## 11. Tools

| # | Mechanic | How to test | Status | Slice |
|---|---|---|---|---|
| 11.1 | New project from the template | `python tools/new_project.py ../my_game "Title"` | Now, changes in P1 | [ ] |
| 11.2 | Episode validation | `tests/validate.tscn` or the editor panel's Validate | Now, changes in P8 | [ ] |
| 11.3 | Step graph panel | select `episode.tres` in the editor | Now, changes in P8 (edit exits, delete, layout) | [ ] |
| 11.4 | Encounter authoring audit | `tools/authoring.tscn -- res://path/episode.tres` | Now | [ ] |
| 11.5 | Debug panel | F3 in a debug build: force exit, jump to step | Now | [ ] |
| 11.6 | Autoplayer route test | policy in `tests/autoplay.gd`, see `tests/test_flow.gd` | Now | [ ] |
| 11.7 | Windows export | `python tools/verify.py --export-windows` | Now, changes in P9 | [ ] |
| 11.8 | Steam Deck / Linux export | export preset | New in P9 | [ ] |

## Hardware sign-off

Not tickable from the editor. Done on real machines at the end (see [WINDOWS_SMOKE_TEST.md](WINDOWS_SMOKE_TEST.md)):

- [ ] Exported Windows build, full playthrough of the slice
- [ ] Physical Xbox controller
- [ ] Physical PlayStation controller
- [ ] Steam Deck
- [ ] Frame rate within budget in the heaviest scene
