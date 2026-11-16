# QTE v2 implementation status

This milestone implements the **software portion of Phases 0–2**, preserving the
original Episode 0 encounters. It does not implement the full 30-mechanic target.

## Completed work and evidence

- **Phase 0 — baseline:** reproduced the original CI leak in three fresh editor
  profiles and traced it to Dialogue Manager's deferred reimport timer. Fixed
  ownership/disposal and its obsolete filesystem API call, retaining strict error
  detection. Three equivalent fresh imports passed; baseline 169 checks, episode
  validation, Windows export and isolated pack startup passed. The fix also passed
  [GitHub Actions](https://github.com/kavemankai/Tail-engine-/actions/runs/43845358372).
- **Phase 1 — seam:** optional `CADGate.interaction`, runner, input router, active
  clock, typed result and shared handler contract. Verified 224 checks at the
  phase boundary, including old story routes, save/rewind, cancellation, pause,
  stale tokens and actual Flow/stage integration. Null interaction retains legacy
  evaluation and buffering. Typed details are additive and encounter-local.
- **Phase 2 — gesture/timing:** timed release, overlapping chords, deliberate
  restraint, graded timing/parry, marker anchoring, explicit early/wrong policies,
  assist tolerances and hitch-safe continuous progress. Tests cover grade edges,
  30/60/120 FPS, pauses/retries, unloading, device changes, remapping, input-source
  ownership and six data-authored lab encounters. A two-bone AnimationTree fixture
  verifies the skeletal adapter and separation of pose from timeline displacement.

Use `python tools/verify.py --export-windows` and Python runner tests for the final
revision. Logs are in `build/logs/`; all leak/script/engine error checks remain on.
The Windows package includes the Interaction lab menu and is pack-startup tested
outside the source checkout. Windows execution and real-pad QA remain separate.

## Selected mechanics

| ID | Mechanic | Current implementation |
|---:|---|---|
| 1 | Single press | Gesture; legacy preserved |
| 3 | Hold | Gesture; legacy frozen-window hold preserved separately |
| 4 | Timed release | Gesture, source-owned release, graded outcomes |
| 7 | Alternating buttons | Outstanding Pattern phase |
| 8 | Simultaneous buttons | Gesture chord with overlap/tolerance and retry/fail policy |
| 9 | Button sequence | Outstanding Pattern phase |
| 15 | No-input | Passive; explicit forbidden set and restrained completion |
| 16 | Reaction window | Legacy and opt-in real-time press window |
| 17 | Perfect timing | Timing and timed release with signed error and graded routes |
| 20 | Parry | Timing-backed resource example; real contact/choreography unverified |
| 21 | Counterattack | Existing graphs can chain beats; reusable compound template outstanding |
| 29 | Directional dodge | Outstanding analogue/sector/rearm evaluator; legacy dodge is a button |
| 30 | Directional block | Outstanding Direction phase |
| 38 | Directional selection | Legacy digital choices only; analogue sectors outstanding |
| 42 | Target selection | Outstanding Target registry/evaluator |
| 43 | Moving target | Outstanding tracking/lock evaluator |
| 53 | Three-punch combo | Existing graph composition only; reusable template/paired clips outstanding |
| 56 | Attack/defence chain | Existing graph composition only; reusable template outstanding |
| 62 | Tug of war | Outstanding Pressure evaluator and accessibility substitute |
| 69 | Grapple escape | Hold is available; compound/opposition/release choreography outstanding |
| 72 | Object grab | Existing flag-conditioned stool choice; generic target/socket ownership outstanding |
| 79 | Timed choice | Legacy and shared Choice; explicit option vs missed decision |
| 84 | Conversation during action | Outstanding focus coordination; concurrent Flow dialogue is currently rejected |
| 89 | Camera perspective | Existing stage timeline cuts/restoration preserved |
| 90 | Slow-motion decision | Independent input clock ready; scoped cinematic slowdown outstanding |
| 94 | Conditional follow-through | Existing validated flag branches preserved |
| 97 | Momentum | Outstanding encounter-local score/context |
| 98 | Observation memory | Existing Story flags and stool unlock preserved |
| 101 | Adaptive choreography | Existing flag routes only; typed actor/prop/momentum context outstanding |
| 107 | Intent | Result field reserved; authored semantic choice mapping outstanding |

## Next phases and open acceptance gates

Continue in the committed order: Direction and counterattack composition; Pattern
and combos; Target/attachments; Pressure/struggle; cinematic/narrative layers;
authoring/trace/1080p quality gate. New families must register in the shared
runner and validation, not add scene-local input scripts or a second story graph.

- Real Windows controller tests have **not** been performed. Synthetic key/pad
  events do not prove driver, disconnect/reconnect or physical UX behaviour.
- The humanoid kit and paired contact clips are unavailable. The minimal rig
  proves interface/playback only; alignment, snapping, foot contact, impacts and
  variant proportions require real assets and visual review.
- No production compound templates, target UI, sockets, resistance, local slowdown,
  barks/live dialogue coordination, momentum or semantic-intent authoring exists.
- New interactions deliberately reject pre-held input and do not consume legacy
  early buffers. Paused incomplete gestures require fresh input on resume.
- Detailed grades are not persisted into Story yet. Legacy strings/checkpoints
  remain compatible; no mid-contact pose serialisation or save migration exists.
