# Roadmap to a shippable engine

The goal is an engine a real game can be built and released on, for Windows and Steam Deck. [MECHANICS_TO_TEST.md](MECHANICS_TO_TEST.md) lists every mechanic and whether it works today.

## Working today

- Episode step graph (Explore, Dialogue, Encounter, Card, Cutscene), conditional exits, seasons with carried variables and earlier-episode choices.
- Dialogue with timed choices and a silence option, story state declared in a manifest, notices and recap.
- Walk-around hubs with hotspots and camera zones.
- Action layer: eight interaction families and five compound templates, with barks, slow motion, momentum and intent.
- Camera cuts, blends, shake, drifting shots, voice playback with loudness-driven mouth movement, recording-script export.
- Checkpoint saves with atomic writes, Continue, rewind, save slots.
- Settings for subtitle size, reading time, timing assistance and master volume; device-aware prompts.
- Editor panel with a step-graph view and validation; headless validator and authoring audit.
- `tools/new_project.py` starter generator; `tools/verify.py` and CI (29 suites) that fail on errors and leaks; Windows export.

## Remaining phases

Each phase lands as its own pull request with tests first.

1. ~~Legal and hygiene.~~ Done.
2. ~~Saves and failure handling.~~ Done, except episode select (moved to phase 3).
3. **UI, input and settings.** Done: options, rebinding, controller button names, history, credits, recap, loading, episode select. Remaining: themed UI scenes that restyle without code, a save-slot screen with details, icon glyphs.
4. ~~Localisation.~~ Done, except per-language voice files.
5. **Audio.** Bus layout, per-step music and ambience, pooled and positional effects.
6. **Direction.** Timeline step driven by an AnimationPlayer, voice and sound in cutscene cues, skipping, emotion/gesture/look-at tags in dialogue, more action-prompt assists.
7. **Exploration.** Camera-relative movement with walk and idle animation, follow camera with collision, hotspot highlighting, examine view, inventory.
8. **Editor.** Editing exits and deleting steps in the graph panel, non-blocking validation, stronger validator.
9. **Platform.** Linux / Steam Deck export, running the exported build in CI, Steam achievements and cloud saves, crash logs, renderer and performance budget.
10. **Hardware sign-off.** A slice episode that ticks every row of the mechanics list, played on a Windows PC and a Steam Deck with physical controllers ([WINDOWS_SMOKE_TEST.md](WINDOWS_SMOKE_TEST.md)).

## Known open risks

- No real controller, GPU or exported executable has been tested; automated tests inject input and use the headless renderer.
- The bundled characters have stand-in fight clips and no facial rig. Paired contact animation is content work for each game.
- The rights to the `narrative_characters` clothing are not recorded; confirm them before shipping a game that includes that addon.

The documents in `research/` describe earlier experiments. Their phase numbers and estimates are historical.
