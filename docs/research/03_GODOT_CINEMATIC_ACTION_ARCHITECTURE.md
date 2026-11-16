# 03 · Godot Cinematic Action Director

**Decision.** Use the hybrid architecture. Let Godot own timeline playback and the existing animator own skeletal playback. Put gates, outcomes and recovery in a thin typed GDScript director. Integrate the existing Dialogue Manager through a project-facing adapter. The first encounter needs native cameras and no additional sequencing dependency.

| Criterion | A · Native tools with scene scripts | B · Event Sequencer and GD-QTE | C · Native timelines, typed director and project adapters |
|---|---|---|---|
| Animation continuity and rigs | Good for one scene. Script per scene can diverge. | Generic calls work. Sync, alignment and actor ownership still need custom code. | Clip and paired-anchor adapters are shared. Timeline remains editable. |
| Controller and accessibility | Possible through InputMap and scene scripts. | Mixed by QTE class. Global time scale and duplicate failure complicate lifecycle. | Stable action IDs with one clock, device routing and accessibility policy. |
| Authoring and reusable branches | Timeline is excellent for shots. Branches tend to become code. | Visual tree is ready for trigger order. No stock shared 3D frame timeline. | One text-friendly beat resource plus native tracks per shot/beat. |
| Dialogue and story recovery | Available via explicit calls. Repeated handoff logic is likely. | Legacy dialogue waits need adaptation. State, cancellation and saves still custom. | One cue-based protocol and idempotent branch commits. |
| Debugging and maintenance | Small initial cost. Higher reuse cost. | MIT core, but old sequencer, optional dependencies and code-driven events. No timing advantage measured. | Shared validators, traces and forced branches. Cost concentrated in small runtime and clip authoring. |
| Performance and licensing | Native engine plus licensed assets. | Additional event dispatch/allocations, unbenchmarked for a production scene. No copied game assets. | Native mixer cost plus one active gate and bounded dispatch. Profile real rigs and bar before optimisation. |

## Scene ownership

```text
EncounterHost (existing game)
  Gameplay + dialogue + narrative-store adapters
  CinematicActionDirector
    BeatTimeline (AnimationPlayer, AnimationLibrary)
    Actor adapters (bindings to existing instances)
    Shot controller (existing camera service or Camera3D)
    InputGate (one active gate)
    PromptView (CanvasLayer and compact control)
  EncounterBindings (role IDs -> actors, shots, Marker3D anchors and prop)
```

The director transitions through Acquire, Setup, Play, AwaitInput, Resolve, PlayBranch and Handback. Preflight all role/clip/marker IDs before Acquire. Issue a monotonically increasing run ID and gate ID. Every signal handler or delayed callback compares its token. Accept or time out once, clear prompt, and record the pending branch. Keep the approach clip alive until its authored branch marker, using a safely extendable anticipation or struggle loop if the accessibility window needs more time. A short window may close before that marker. Time elapsed during explicit pause/focus suspension is excluded. Complete a branch at a named safe marker, then commit outcome and resume a named dialogue cue. Ensure the common cleanup path restores camera, locomotion, interactive focus, dialogue UI state, prompts and any temporary prop/animation overrides.

A method track should emit a small vocabulary such as `open_gate(id)`, `commit_cut(id)`, `cut_to(shot)` and `play_actor_clip(role, clip)`. Use markers or typed calls without narrative mutations in seekable tracks. Scrubbing or previewing can play poses and shots. Save writes, QTE launches and world ownership occur only during a live encounter. Test deferred method calls, frame crossing and stop/seek semantics. Bind animation-finished signals only where clips do not loop, filter by animation and token, and set a bounded recovery watchdog.

**Playback ownership.** Use the currently deployed animation API for each actor. Where the rig uses AnimationTree, drive the tree state/OneShot and avoid racing direct player calls on the same skeleton. The director's AnimationPlayer controls cinematography and cues, while the actor's player/tree controls pose. Use audio tracks for authored contact cues or dispatch one-shots from contact markers. Keep music stems independent of short gate-time tweaks.

## Use the existing humanoid kit

The available standalone kit is `Godot-Humanoid-Kit`, with Godot 4.6 project features. Its `Humanoid.tscn` is a CharacterBody3D with `$Visual`; `animator.gd::configure` looks up imported `GeneralSkeleton`, creates AnimationPlayer, loads portable in-place and root-motion libraries, and mounts optional `extra_animations` under `extra/`. `play_action(request)` rejects looping and `root_motion/` clips, aliases common actions and uses a default 0.16 s fade. `update_motion` skips locomotion while an action is active. `humanoid.gd::_physics_process` still manages velocity, facing and ground state. `player.gd` has independent control and camera code. Calling `set_ai_enabled(false)` alone will not lock player control or disable body physics. The kit uses its available Superhero base variants, maps via `base_map.tres` and `ual_map.tres`, and records CC0 source assets. The production The Static checkout and Windows Conversation Characters folder were unavailable here. Its prior handover is a design record, not an inspection of deployed scripts.

- Add a negotiated `acquire_cinematic_control(run_id)` adapter to the real actor/controller. Save movement/camera/AI state, stop input and pathing, settle velocity, then let the encounter own actor placement. On scene unload release safely. The proof temporarily disables physics on its own static actors. Production needs explicit collision/ground policy and safe release points.
- Preserve the skinned model and runtime skeleton. Compare parent chain, rest rotations and scale, root convention, track paths, and named contact bones before reuse. Inspect clip loop modes, contact timing and end pose. Keep paired clips together in one library or authored package. Use the existing BoneMap for additional licensed clips that need retargeting. Godot humanoid profile names alone do not guarantee compatible rest poses or paired contact.
- For a stationary exchange, align actors to `Marker3D` transforms under an encounter anchor. For each role, desired world pose is `anchor.global_transform * role_offset`. Choose positions/angles per body variant, validate collision clearance, and align with a motion-matched step or behind a motivated cut. Derive actual hand/prop and body/target distances at the contact frame. Preserve feet during contact and fix mismatch in clip authoring first.
- In-place clips get one authority for displacement. Match root curves to planted feet, or extract root-motion deltas with AnimationMixer and apply to the body. Never animate the body forward and apply the same skeletal displacement. Use a real collision sweep in free-space movement. Scripted contact zones may use reserved blocking space. In both cases, preserve final position on handback.
- Match a branch's first sampled pose, root transform, velocity and held prop to the source pose. Author a short transition when they differ. At handoff, use a deliberate cut or interpolate from the real active camera. For grabs, use a shared origin, explicit hand socket via `BoneAttachment3D`, and detach only at authored markers. Tune foot/hand IK only where variant proportions leave visible error.

References: [Godot 4.6 retargeting](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html), [AnimationPlayer](https://docs.godotengine.org/en/4.6/classes/class_animationplayer.html), [AnimationTree](https://docs.godotengine.org/en/4.6/classes/class_animationtree.html), [AnimationMixer](https://docs.godotengine.org/en/4.6/classes/class_animationmixer.html), [Skeleton3D](https://docs.godotengine.org/en/4.6/classes/class_skeleton3d.html), [Quaternius](https://quaternius.itch.io/universal-base-characters).

## Authoring contract

| Source | Owns | Reviewability |
|---|---|---|
| Encounter `.tres` typed resource | Stable ID/revision, role/flag contracts, entry beat, references, named exits and checkpoint policy | Diff the graph and asset references. Validate via headless script. |
| Beat `.tres` or embedded subresource | Timeline animation names, markers, typed gate spec, allowed targets, exit/next IDs and allowlisted effects | Compact changes for one decision and its outcomes. Use independent stable IDs instead of array index jumps. |
| Scene `.tscn` and AnimationLibrary | Staging, camera nodes, anchors, track keys, prop placement and optional audio | Inspect and preview in the native editor. Script direct edits to small resources or scene anchors. |
| JSON | Sample schema, traces or optional tooling I/O | Ship scene resources as the source of truth. Add a one-way importer only when there is repeated authoring demand. |

Each gate declares `kind` (press, direction, hold, target, choice), `action` or choices, `open_marker`, `decision_marker`, `window_ms`, `success/timeout` destinations, optional target IDs, assist policy and progress presentation. Each beat declares entry and exit poses, a non-looping timeline or bounded/explicit loop, camera and audio through named tracks, effects to apply at the terminal checkpoint, and optional fallback. Unit-test gate policy with an injectable clock. Validate graph reachability, terminal outcomes, loop policy, disjoint outcome IDs, referenced clips, unique markers, coherent chronology, role bindings, present InputMap actions and dialogue cues. Preview entry→branch→handback and dump frame, gate elapsed time, chosen route, last cue and camera in debug builds.

Sample authoring data (illustrative JSON representation of typed resources, provided as `sample_bar_encounter.json`). The live proof in 05 uses a single hardcoded exercise so it can answer integration questions without prematurely implementing the graph.

## Dialogue, saves and interruption

The game's existing Dialogue Manager resource contains named cues. The host reaches an authored handoff cue, stops advancing and closes or suspends its own balloon, then acquires the encounter. The director translates each outcome to a resume cue. The host invokes the deployed DM API and reopens its normal compact dialogue. Distinguish a normal dialogue end from an interruption. Scope dialogue callbacks to the resource and conversation token so unrelated dialogues cannot resume the fight. Verify the production addon version first. The audited 4.2 code exposes `passed_cue`; the older sequencer expects `passed_title`.

Persist an encounter revision, run/checkpoint ID, allowlisted outcome values, recovery marker, and intended dialogue cue through the existing game save service. Save before acquisition and at a safe post-branch checkpoint. During active choreography, queue a save or restart at the last reconstructible checkpoint after load. Restore world props and flags from the checkpoint snapshot and re-open the cue by ID. Use a stable commit key to avoid applying health/trust changes twice. Keep timeout/failure separate from cancellation, device loss and scene unload. Cancellation drops uncommitted effects, cancels the gate and restores the input lease. Do not serialize animation coroutine state or mid-contact physics objects for this slice.

## First production encounter

Hostile dialogue → step/shoulder wind-up → timed directional dodge → successful evasion or glancing hit into the counter → shared footing → select stool block if available or step away → authored prop response and NPC reaction → end flag and dialogue cue. Keep a glancing hit consequential through follow-up dialogue or reputation, with progression intact. Bind the stool, cameras and actor slots in each scene. The encounter schema holds no hardcoded bar node paths. Use one bench/stool state and a short recover cue before handing exploration control back.
