# Tail Engine — QTE Architecture v2 and Implementation Roadmap

**Status:** Target architecture; software Phases 0–7 are implemented on the development branch. See [QTE_STATUS.md](QTE_STATUS.md) for verified coverage and outstanding phases. Hardware and real-humanoid acceptance remain open.
**Baseline audited:** `kavemankai/Tail-engine-`, default branch `ccr-a20ee9e7-3y4ohl`, commit `8aaefe08dad93327bf98e383a6a615e2fcc32987` (16 November 2026).  
**Engine target:** Standard Godot 4.6.3, GDScript, controller-first Windows/1080p.  
**Scope:** Exactly the 30 selected mechanics below. This document changes no runtime behaviour.

## Decision

**Extend rather than replace the existing Cinematic Action Director (CAD).** Keep `CADSequence`, `CADBeat`, `CADGate`, `CADOption`, `CADStage`, `CADDirector`, existing Tale Engine `Flow`, `Story` and Dialogue Manager integration. Separate input evaluation from scene direction. Build **eight reusable input handlers**, a **compound-action authoring layer**, and shared **cinematic/narrative modifiers** rather than 30 bespoke QTE implementations.

The actor/stage timeline creates the spectacle; input handlers determine what the player attempted and how accurately; the director commits one named route to the encounter graph. Gameplay remains fail-forward wherever narratively appropriate.

## 1. Source-level implementation audit

This is a **static code assessment**, not a claim that each feature passed a physical-controller or visual test. The repo's existing Godot test suite has tests for press, hold, early input buffering, several routes, interruption, save and cancellation. Those are relevant evidence, but they do not prove the new mechanics below.

| # | Mechanic | Status at baseline | Evidence / gap |
|---:|---|---|---|
| 1 | Single press | **Implemented** | `CADDirector._input` resolves `CADOption.action` on press |
| 3 | Hold | **Implemented** | `CADOption.hold_seconds`; `CADDirector._tick_gate` |
| 4 | Timed release | **Missing** | No release-edge challenge evaluation |
| 7 | Alternating buttons | **Missing** | No pattern evaluator |
| 8 | Simultaneous buttons | **Missing** | No chord evaluation / tolerance |
| 9 | Button sequence | **Missing** | No ordered action evaluator |
| 15 | No-input QTE | **Partial** | Timeout exists, but restraint success is not a distinct mechanic |
| 16 | Reaction window | **Implemented** | Gate window, timeout, open marker, buffering |
| 17 | Perfect timing | **Missing** | Binary outcomes only; no graded timing |
| 20 | Parry | **Partial** | Timed press possible, no contact-aligned parry grade/template |
| 21 | Counterattack | **Partial** | Branches can chain defence and attack; no reusable compound definition |
| 29 | Directional dodge | **Partial** | `cad_dodge` is a button; direction is not evaluated |
| 30 | Directional block | **Missing** | No corresponding true directional evaluation |
| 38 | Directional selection | **Basic** | D-pad InputMap choices exist; analogue selection missing |
| 42 | Target selection | **Missing** | No target registry/selection evaluator |
| 43 | Moving target | **Missing** | No track/lock evaluator |
| 53 | Three-punch combination | **Partial** | Beat graph can express three steps; no reusable combo contract |
| 56 | Attack/defence chain | **Partial** | Sequential graph composition possible; no declarative template |
| 62 | Tug of war | **Missing** | No opposed progress evaluator |
| 69 | Grapple escape | **Partial** | Existing hold/timed beats can approximate; not a reusable compound |
| 72 | Object grab | **Partial** | Conditional stool choice exists; no generic target/prop attachment |
| 79 | Timed choice | **Implemented** | Multiple `CADOption` routes and `CADGate.window_seconds` |
| 84 | Conversation during action | **Missing** | `TEFlow` schedules dialogue and encounter steps separately |
| 89 | Camera perspective | **Implemented** | `CADStage.cut` through `AnimationPlayer` method tracks |
| 90 | Slow-motion decision | **Missing** | No independent local cinematic-time policy |
| 94 | Conditional follow-through | **Implemented** | `CADBranch.requires` and `CADOption.requires` |
| 97 | Momentum | **Missing** | No scoped momentum score |
| 98 | Observation memory | **Implemented (basic)** | `Story.vars` feeds encounter flags; prior stool observation unlocks action |
| 101 | Adaptive choreography | **Partial** | Flag-based route selection only; no typed actor/prop/momentum context |
| 107 | Intent | **Partial** | Choices already route actions; no explicit semantic intent result |

Evidence files:
- `addons/cinematic_action_director/{cad_director,cad_gate,cad_option,cad_sequence,cad_beat,cad_stage,cad_prompt,cad_input_device}.gd`
- `addons/tale_engine/{te_flow,te_story,te_actor,te_balloon,te_settings}.gd`
- `content/episode_0/encounters/{bar_fight,alley_chase}/encounter.tres`
- `tests/{test_cad,test_flow,test_lifecycle,test_save}.gd`

**Existing CI blocker:** The current default-branch GitHub Actions job fails during Godot's **headless editor import**, with `WARNING: ObjectDB instances leaked at exit`, before Godot suites or Windows export execute. The Python unit tests pass. Diagnose leak with verbose import and preserve strict checks; do not suppress the warning to get a green build without investigating. Run: https://github.com/kavemankai/Tail-engine-/actions/runs/43836715367

## 2. QTE mechanic families: eight evaluators

Each handler is a pure input/progress evaluator as far as practical. It receives a normalised event, active-clock time, immutable spec, and permitted challenge context; it emits progress and at most one `CADResult`. It does **not** know the name of the bar, play an animation, change story flags, or control a camera.

| Handler | Direct mechanics | Contract |
|---|---|---|
| **Gesture** | 1, 3, 4, 8 | Press, hold, timed release, simultaneous chord |
| **Pattern** | 7, 9 | Ordered / alternating mapped actions; permitted error policy |
| **Timing** | 16, 17, 20 | Reaction window, accuracy grade, contact-aligned parry |
| **Direction** | 29, 30, 38 | Digital/analogue sector, flick/hold/selection, re-arm thresholds |
| **Target** | 42, 43, contributes to 72 | Eligible static/moving targets, reticle/focus, acquire/lock |
| **Pressure** | 62, contributes to 69 | Bounded opposed-progress and resistance curve |
| **Choice** | 79, contributes to 107 | Timed choices and optional semantic intent |
| **Passive** | 15 | Deliberately refrain, wait or remain neutral; distinguish success from ordinary timeout |

All other selected mechanics are **compositions or modifiers**:
- **Compound templates:** counterattack (21), three-punch combo (53), attack/defence chain (56), grapple escape (69), object grab (72).
- **Concurrent interaction:** conversation during action (84) is a Tale Engine/Dialogue Manager coordination capability, not a new QTE evaluator.
- **Cinematic modifiers:** camera perspective (89), local slow-motion decision (90), conditional follow-through (94).
- **Narrative/encounter context:** momentum (97), observation memory (98), adaptive choreography (101), intent (107).

### Behavioural requirements for handlers

**Gesture:** recognises physical press/release edges, debounces key repeats, defines chord tolerance and a neutral-to-active re-arm policy. A hold that began before gate acquisition must not auto-complete unless the authored spec explicitly permits carried input. Timed release must determine early/on-time/late from the release edge.

**Pattern:** uses a list of action IDs, explicit per-step deadlines and a policy for wrong input (ignore, reset, fail or branch). Alternating is a generated sequence rather than another engine class.

**Timing:** stores an authored ideal instant/interval relative to the gate's live clock or choreography marker; grades `perfect/success/partial/miss` only when configured. A wrong or early input has a declared policy, not an automatic penalty. Never infer timing from frame count alone.

**Direction:** sample stick axis/keyboard/D-pad into one logical sector; use configurable activation and re-arm thresholds with hysteresis. Reject stale directions that remained held from exploration or dialogue. Explicit diagonal sectors and stick-relative vs camera-relative definitions.

**Target:** obtain selectable target IDs from a stage-side registry; expose world-to-screen projection or focus cycling, with deterministic tie-breaking. Never allow a UI widget to grant story state directly. Moving-target tracking is a sampled lock/progress challenge, not an implicit hit-scan combat system.

**Pressure:** progress in [0,1], scriptable opposition and recovery, deterministic bounded updates, and an alternative accessibility input. Do not accidentally turn this into mandatory rapid-mashing.

**Choice:** produces stable action/intent IDs, not display strings. Distinguish a missed timed decision, an intentional abstention and default selection.

**Passive:** requires an explicitly authored forbidden-input set and a completion time/event. No-input is not synonymous with gate timeout.

## 3. Proposed runtime contracts

Introduce optional typed resources without breaking existing `.tres` encounter files:

```text
Tale Engine (TEFlow, Story, DialogueManager)
  -> CADDirector                  [encounter graph, lifecycle, exact-once route]
     -> CADStage                  [AnimationPlayer timeline, actors, shots, props]
     -> CADInteractionRunner      [one active spec and one handler]
        -> CADInputRouter         [InputMap, controller/keyboard/mouse]
        -> CADClock               [pausable input clock]
        -> CADResult              [typed grade/route/progress/metadata]
        -> handlers/
           Gesture, Pattern, Timing, Direction,
           Target, Pressure, Choice, Passive
     -> CADPrompt / presentation  [compact mapped glyph + progress]
     -> optional CADCompoundAction templates [authoring-time graph composition]
```

New `CADInteractionSpec` is optional on `CADGate`. **If absent**, run the existing `CADOption` press/hold code path exactly as today. Avoid introducing a second standalone story graph. Keep `CADSequence` as the authoritative graph; templates produce/reference existing beats and transitions.

Suggested `CADResult` values:
- `challenge_id`, `beat_id`, `visit_id`, `run_id`
- `option_id` / `intent_id` / `target_id` (where applicable)
- `grade`: `perfect | success | partial | miss | timeout | restrained | cancelled`
- `timing_error_ms`, `progress` and small allowlisted metadata
- `route_id` resolved from spec, separate from the grade

Do **not** persist arbitrary InputEvent objects, scene Node references or unbounded execution state. Retain current `director.results` legacy option/timeout mapping for old consumers; introduce detailed per-gate results without silently changing their data shape.

**Clock and determinism:** one monotonic gate timebase with explicit pause/focus suspension and injectable time for unit tests. Avoid coupling challenge deadlines to `Engine.time_scale` or cinematic animation speed. Specify deadline tie policy and one-shot resolution. Validate at 30/60/120 FPS and under a simulated frame hitch. Carry an encounter/run token and gate/visit token through asynchronous callbacks; discard stale events after rewind, cancellation, scene unload or retry.

**Input ownership:** only one active gameplay owner for a control. When Tale Engine hands off dialogue/exploration to CAD, neutralise/re-arm overlapping actions such as confirm/dodge. Simultaneous-button and hold interactions need explicit transition rules for inputs already physically down. Map to logical actions, not hardcoded Xbox glyphs. Prompt view reads from InputMap and refreshes for the last meaningful device.

**Animation:** handlers report outcome; director selects route; `CADStage` uses timelines for camera/prop/shot control and actor-specific `cad_act(clip)`/AnimationTree adapter for skeletal clips. A proper paired attack/reaction library must align actors, root displacement, contact frame, branching entry/exit poses, and prop sockets. No generic input handler should assume those clips exist.

**Target / prop attachment:** separate interaction eligibility (CADTargetRegistry) from physical ownership and bone attachments (`BoneAttachment3D` or authored sockets). Use authored pickup/attach/detach markers and deterministic cleanup after cancellation.

**Save/restore:** commit durable `Story` state at safe branch/checkpoint boundaries, not when the player merely taps a button. Preserve checkpoint-based restart, exactly-once effects and legacy saves. Do not serialise mid-contact skeletal poses for the first version.

**Slow motion:** locally change only authored cinematic playback and relevant effects; input deadlines must stay on an independent clock. A slowed camera/actor track must provide sufficient anticipation/continuation for assisted reaction windows. Avoid global timescale changes unless fully isolated, explained and tested.

**Dialogue during action:** start with brief voiced/subtitled barks or timed choice overlays owned by a single input-focus coordinator; only later implement a live Dialogue Manager balloon during action, with explicit suspend/resume and cue handoff. Avoid two systems responding to the same confirm button.

## 4. Example compound actions

### Three-punch combination (#53)
`windup -> jab_gate -> jab_land_or_block -> cross_gate -> cross_land_or_block -> finisher_gate -> finish_or_recover`

- Each successful press triggers a corresponding **paired** actor animation and camera/audio key.
- A missed middle punch selects an interruption/blocked-strike branch or recoverable follow-up; do not reset the entire encounter by default.
- Gates and animations have stable IDs. Authored transitions match poses/position between branches.
- Optional momentum increases on accurate inputs; momentum does not drive animation selection implicitly.

### Counterattack (#21) / attack-defence chain (#56)
`telegraph -> direction_or_parry -> evade/block/hit -> optional counter input -> contact/recovery`

- The player can succeed defensively but fail the counter without retroactively losing the dodge.
- A graded parry can open a distinct high-impact response.
- Camera cuts must preserve body orientation and screen geography.

### Grapple escape (#69)
`grapple_enter -> directional_move -> opposed_pressure -> release_at_opening -> escape_or_stagger`

- Compound steps may use different handlers but the same overarching CADSequence.
- Strong accessibility substitute for pressure/alternating input.
- Explicit acquired/released actor and prop ownership.

### Object grab (#72)
`threat -> target selection -> reach / miss -> attach prop -> use/throw -> detach / restore`

- Target IDs are authored stage bindings.
- Environment observation (e.g. `stool_noticed`) can affect **whether** the option is offered.
- The stage commits exact transforms and prop ownership, not the input handler.

### Semantic intent (#107)
Select `escape | defend | restrain | intimidate | injure`. The intent is a stable result/branch input and may restrict allowable follow-through. It is **not** a substitute for bespoke matching animations.

## 5. Cinematic and story modifiers

- **Camera perspective (#89):** already supported by `CADStage.cut`; add authored prompt-safe-area / 3D anchor constraints and camera-owner restoration tests.
- **Slow-motion decision (#90):** use scoped animation playback speed and normal-speed gate timing. Restore speeds in all exits, including cancellation.
- **Conditional follow-through (#94):** retain old `requires` flags, add validated typed predicates only where plain flags cannot express a need. Avoid arbitrary evaluator code stored in content.
- **Momentum (#97):** bounded encounter-local score, e.g. 0–3 or 0–5, adjusted by specified result grades. Expose to authoring predicates, not a full combat simulator.
- **Observation memory (#98):** use `Story` variables and optional recap/consequence data. Already proven by stool selection; no new handler.
- **Adaptive choreography (#101):** select from prevalidated authored branches based on intent, injuries/actor status, prop availability, momentum, and story flags. Do **not** assemble arbitrary two-character clips at runtime and assume correct contact.
- **Conversation during action (#84):** treat as a Tale Engine integration layer; input ownership, subtitles, audio cue priority and cancellation are part of acceptance.

## 6. Backward-compatibility and test contract

The baseline must remain loadable:
- `CADGate` without `interaction` uses exactly the existing `CADOption.action`, `hold_seconds`, `requires`, `timeout_next`, `open_marker`, `buffer_seconds` and `cut_on_resolve` semantics.
- Existing scene animation method markers and camera slots remain valid.
- Old `Story.results`, `Story.outcomes`, checkpoints and named dialogue cues continue to work.
- Only one active gate per director; exactly one result per visit. `cancel`, `suspend`, `watchdog` and viewport-control lease still work.
- New spec validation rejects broken references, unsupported result grades, missing InputMap actions, invalid target IDs, impossible windows, unsafe cycles and broken compound routes.
- Tests cover incorrect/early/late/missing input, simultaneous press within/outside tolerance, sequence recovery, stick rearm, timing grade boundaries, target changing while tracking, pressure with variable frame delta, multiple controllers, device switching, lost focus, rewind, actor deletion, nested callbacks and stale signals.
- Test synthetic joypad events **and** run a physical Xbox-compatible pad on Windows. Synthetic events alone do not certify hardware compatibility.

## 7. Incremental roadmap and acceptance gates

| Phase | Build | Required verification |
|---|---|---|
| **0 — Baseline stability** | Diagnose/fix current headless import leak, run existing tests, validate exported pack and physical Windows smoke test | Clean import; all nine existing test suites and validation pass; Windows export completes; issue fully diagnosed |
| **1 — Interaction seam** | Optional `CADInteractionSpec`, runner, router, clock, result model and legacy adapter | Existing bar fight/chase routes unchanged; cancellation/pause/rewind and save tests remain green |
| **2 — Timing/gesture completeness** | Timed release, simultaneous chord, passive restraint, timing grades, contact-aligned parry | Automated early/perfect/late/timeout/release tests and distinct route outcomes |
| **3 — Directional combat** | Analogue/digital direction handling, directional dodge/block/choice and counterattack composition | Correct/wrong direction, held-stick rearm, D-pad/keyboard fallback, paired camera/animation reactions |
| **4 — Patterns and combos** | Alternating inputs, ordered sequence, three-punch combo and attack/defence chain templates | Three distinct synced punch animations; interruption/recovery path; robust wrong-input and timing tests |
| **5 — Environmental targets** | Target registry, static/moving target UI, object grab and authored attachment points | Real humanoid grabs prop; alternate/no-target routes; restore prop and actor state after cancellation |
| **6 — Physical resistance** | Opposed-pressure evaluator and grapple-escape compound | Deterministic progress, partial outcomes, assist alternative, escape and failure clips |
| **7 — Cinematic/narrative layers** | Scene-local slowdown, barks/timed dialogue during action, momentum, typed context and semantic intent | No audio/input-focus conflicts; save/rewind stable; authored adaptive variants preserve posing |
| **8 — Authoring and quality gate** | Reusable templates, validator enhancements, debug trace/visualisation, controller and 1080p tests | New fights/chases authored as data and timelines without modifying CAD runtime; full CI/hardware QA |

Complexity is primarily in matching multiple humanoid animations, camera cuts and prop contact—not in accumulating QTE evaluators. Build and validate in this order; stop to correct architectural faults before adding families.

## 8. Three acceptance showcases

1. **Bar fight:** prior stool observation unlocks object targeting; timed directional dodge / graded parry; three individually triggered punches with paired reactions; camera changes; choice to restrain or escalate; distinct narrative outcome.
2. **Alley chase:** jump/roll chain, direction choice, early/late/missed timing, alternate stumble/capture, and controlled cinematic camera cuts.
3. **Physical struggle:** directional grapple response, opposed-pressure meter, timed release, deliberate no-input restraint option, separate success/partial/failure animations.

For every showcase, verify **actual humanoid rigs** on the existing `TEActor` adapter; proper two-actor alignment, foot contact, impacts, camera continuity and readable UI. Placeholder capsules or passing unit tests do **not** establish cinematic quality.

## 9. Explicit non-goals

- No full Arkham-style combat AI, free-form hitbox simulator or animation generation at runtime.
- No 30 independent QTE classes or parallel story graph.
- No third-party addon introduced solely because it exists.
- No rewriting existing encounters to the new schema all at once.
- No new bespoke editor until repeated authoring friction justifies it.
- No changes to production runtime until Phase 0 is green and Phase 1 is tested on an isolated branch.

## 10. Next implementation assignment

**First fix/diagnose the failing import-stage CI run without weakening validation.** Then implement Phase 1 as an additive, backwards-compatible seam with a regression test covering both existing encounters. Only after that should the new handlers be built. Confirm real Windows controller behaviour and humanoid paired contact early rather than leaving those risks until the end.

**This document describes the full target, not proof that all its proposed additions exist. Use [QTE_STATUS.md](QTE_STATUS.md) for current implementation and verification evidence.**
