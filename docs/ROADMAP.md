# Current demo roadmap

The milestone is a dependable Windows desktop greybox demo of Episode 0.
Keep the existing episode/resource APIs and single menu save slot. Real assets
are a later milestone, with selection and licensing decided before integration.

## Implemented

- Exploration, timed dialogue, story choices, branching bar fight and alley chase,
  recap, checkpoints, Continue and rewind, backed by route tests.
- Pinned Godot 4.6.3 verification and restored upstream Dialogue Manager SVG import
  metadata. Clean checkout imports without relying on an existing UID cache.
- Save shape/resource/checkpoint validation, atomic file replacement and failure
  notices. Invalid saves do not interrupt an active session; version-1 saves stay
  supported. New manifest variables retain their defaults when restoring a save.
- Explicit conversation/exploration cancellation, generation-scoped flow cleanup,
  fade cancellation, paused dialogue clocks/audio and interruption regressions.
- Shared device-aware prompts and title/pause settings for subtitles, volume,
  reading speed and timing assistance, with persistent configuration.
- Windows x86_64 export preset and GitHub Actions verification/artifact workflow.
- QTE v2 optional interaction seam, monotonic pausable input clock, typed results,
  remapping/rearm and exclusive action input. Legacy Episode 0 gates are preserved.
- Shared Gesture, Choice, Timing and Passive evaluators, six resource-authored lab
  encounters and a skeletal AnimationTree adapter fixture. See [QTE_STATUS.md](QTE_STATUS.md)
  for the implemented subset and later phases; this is not all 30 mechanics.

- Directional flick/block/selection, camera-frame snapshots and input rearm, plus
  a reusable counterattack template and opt-in Episode 0 directional variants.
  Pattern sequences and shared combo/attack-defence chain templates now have lab
  examples and regression coverage. Target/pressure and later cinematic layers
  remain outstanding.

## Before sharing the demo

1. Run `python tools/verify.py --export-windows` on the final revision. Confirm
   clean import, all fifteen suites, episode validation and Windows packaging.
2. Complete [the Windows smoke test](WINDOWS_SMOKE_TEST.md) on a real PC and
   physical controller. Record the build commit and device details. This includes
   all four routes, relaunch/Continue, rewind, focus loss, device switching and
   settings. Automated input injection does not establish hardware compatibility.
3. Review the captured playthrough and text layout at both specified resolutions.
   Resolve any graphics, input or readability issues before calling it tested.

## After the greybox milestone

- Select licensed character rigs and a minimal compatible animation set. Prove
  one paired wind-up/dodge/hit sequence through `TEActor` before restaging the
  whole encounter; review contact and branch poses at full speed and frame-step.
- Then add environment art, sound, voice and a consistent UI treatment. Facial
  animation, lip-sync, multiple menu save slots and a custom authoring editor stay
  deferred until the sample demonstrates a need.

The documents in `research/` describe earlier experiments and initial proposals.
Their phase numbers and estimates are historical, not the current task backlog.
