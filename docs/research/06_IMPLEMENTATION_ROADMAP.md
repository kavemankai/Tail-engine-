# 06 · Historical implementation roadmap

This is the original research-stage proposal. The episode runtime and encounter
seam described below have since been implemented. Use [the current roadmap](../ROADMAP.md)
for demo priorities, completed reliability work and Windows release gates.

Estimates assume working existing Godot actors, a populated bar scene and access to the game's current project. They express developer effort, not a fixed schedule. Runtime code and animation authoring have different bottlenecks.

| Priority | Work | Complexity and acceptance |
|---|---|---|
| 0 | Inspect production interfaces on an isolated branch or copy | 0.5–1 day. Record exact Godot/DM versions, input map, scene ownership, gate to compact dialogue handoff, player lock, rig rest/track paths, reusable contact clips and save flag service. Run baseline and preserve output. |
| 1 | Add first vertical seam with one typed beat | 1–2 days. Introduce Encounter/Beat/Gate resources, scene-role bindings, adapter, one press gate, native timeline, two branches, cue handback and trace. Validate missing/invalid role, branch and action references. Prove exactly one outcome and cleanup on timeout, replay, scene unload and focus loss. |
| 2 | Stage two paired clips in the bar | 2–4 days depending on assets. Pair wind-up and dodge/hit, unify animation start pose, fix contact/rest/stride. Establish a two-shot and close shot. Place a directional cue and synced contact audio. Record both paths with the existing humanoids. Require believable motion at full speed and frame-step. |
| 3 | Add the prop decision and lasting consequence | 1–3 days. Place stool socket and fallback branch. Use two prevalidated options, a simple displaced-prop state and a one-flag bartender reaction. Resume normal exploration and test reload/resume. Gate assist timing uses a safe loop and tests both routes. |
| 4 | Harden input, readability and branch continuity | 1–3 days. Run physical controller matrices, audibly/caption-presented cues, rebinding, reduced motion, extended/untimed gates and interruptions. Track input occurrences and exact-once writes. Test staging across character variants and viewport sizes. |
| Later | Add shared hold/targeting, chase spline beats or higher-order composition | Build on a second real encounter. Add nested groups, a preview editor, optional Phantom Camera, body IK or telemetry only when scene authoring demonstrates the need. |

## Reuse immediately

- Native animation library/player tracks and Camera3D. Use the scene tree editor and Animation panel.
- Existing Humanoid Kit rigs, compatible clips, portable libraries and actor resource patterns.
- Current Dialogue Manager assets and compact balloon if verified in production. Use named cues and game-owned flags, following the test seam in 05.
- Existing input mappings, glyph assets and settings where available, after checking for shared focus/remap actions.

## Adapt

- Use the actor's current movement, animation and camera authority behind a small lease adapter. Add a way to freeze or hand off body/root movement cleanly.
- Reuse stationary one-shots, retime paired contact and tune branch exit transforms. Retarget a missing clip only if available licence and matching anatomy permit it.
- Map the camera and UI to existing dialogue layouts. Use native camera cuts initially. Keep sequence input consumption isolated from gameplay.
- Set up a test project/carrier scene or disposable branch for development. Continue with the same humanoid assets.

## Develop

- Typed encounter graph and validation, one exactly-once gate, branch resolution and scene binding contract.
- Story outcome/checkpoint transaction and cue recovery. Use defaults for absent optional props. Add tests for restart and reused actor instances.
- Compact controller-first UI supporting timing assist, re-arm and success/timeout feedback. Expose a debug overlay to force branches, inspect timelines and report cleanup state.
- First paired bar-beat animation coverage, synced prop response, voice/grunt/scrape sounds and alternate acknowledgement.

## Risks to burn down early

| Risk | Fastest experiment |
|---|---|
| The production player or AnimationTree overwrites a choreographed pose | Instantiate real actor twice, lease only one then both, confirm pose, translation and re-enable path. |
| Branch flash, snap or foot slide | Align contact/exit anchors in viewport. Check hands, feet and silhouette frame-by-frame across both transitions and all rig variants in scope. |
| Prompt consumes dialogue confirm or drops a held stick | Use physical controller, re-arm between modes, test motion across device loss and frame hitch with a debug trace. |
| An unbounded dialogue/animation wait locks gameplay | Force timeout, unload, abort and retry. Resume through token-scoped callbacks and a bounded timeout. |
| Pause, camera or save releases twice | Test session transition idempotency and reload at the last safe checkpoint. |
| Too many bespoke clips undermine productivity | Use one encounter anchor, one short attack, two reactions and one prop. Expand only after contact and handback are readable. |

## Original coding assignment (historical)

Build Phase 0 and Phase 1 in an isolated production checkout. Start with `docs/INTEGRATION.md` in the Conversation Characters package when accessible. Deliver one authored `.tres` beat and one `.tscn` shot setup, a named Dialogue Manager cue before and two after, both outcomes as signals and one checkpoint record. Use the existing humanoid rigs and animation libraries, and put any newly sourced pair into the same retargeting pipeline. Include a Windows 4.6.x controller pass and brief recordings of both routes, plus the known limits. Leave the main branch untouched until this seam is accepted.
