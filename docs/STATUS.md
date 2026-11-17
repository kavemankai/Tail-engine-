# Status: what is done and what is left

Last updated 17 November 2026, after pull request #16.

The goal is an engine a real game can be built and released on, for Windows and Steam Deck. Work is split into ten phases. Phases 0 to 4 are done apart from the leftovers listed under each; phases 5 to 10 have not been started. Work is paused here.

For a per-mechanic view (what you can author today and how), see [MECHANICS_TO_TEST.md](MECHANICS_TO_TEST.md).

## At a glance

| Phase | Subject | State | Pull requests |
|---|---|---|---|
| 0 | Mechanics-to-test list | Done | #10 |
| 1 | Legal and repository hygiene | Done, two small leftovers | #11, #13 |
| 2 | Saves and failure handling | Done, one leftover | #12 |
| 3 | UI, input and settings | Mostly done, three leftovers | #14, #15 |
| 4 | Localisation | Done, two leftovers | #16 |
| 5 | Audio | Not started | |
| 6 | Direction (cutscenes and performance) | Not started | |
| 7 | Exploration | Not started | |
| 8 | Editor and authoring tools | Not started | |
| 9 | Platform and release engineering | Not started | |
| 10 | Hardware sign-off | Not started | |

Automated checks: 29 suites, 1,120 checks, run by `python tools/verify.py` and by CI on every push.

## Done

### Phase 0: mechanics list
- `docs/MECHANICS_TO_TEST.md`: about 150 mechanics, each with how to author it and whether it works now.

### Phase 1: legal and hygiene
- Proprietary `LICENSE`; third-party notices in `docs/ASSET_AND_LICENSE_REGISTRY.md`.
- Unused bar environment removed (`assets/`, `scenes/`, `scripts/environment/`).
- `tools/new_project.py` fixed: keeps Dialogue Manager's import metadata and translation settings, copies the authoring guides, licence and notices. Its test boots a generated project in Godot.
- Stale documentation corrected; `CHANGELOG.md` added.

### Phase 2: saves and failure handling
- Save format version 2 with migration from version 1.
- Saves are repaired after a content patch instead of discarded; `TEEpisode.renamed_steps` and `TEStoryManifest.renamed_variables` carry renames.
- Backup of the previous save, with fallback when the newest is damaged. Slot status and details (`TESave.last_status`, `TESave.info`).
- Finishing an episode of a season moves the save to the next episode.
- Runtime faults stop the episode with `Flow.episode_failed` and a message; `*` exits no longer match `error` or `cancelled`. Faults go through `TEFault`.
- Undeclared story variables and options are reported and not stored.
- Losing the controller in use pauses the game; an open action prompt survives its controller being unplugged.
- Confirmation before overwriting a save, rewinding, and quitting to the menu.

### Phase 3: UI, input and settings
- Settings: Music / Effects / Voice volume on their own buses, fullscreen, vertical sync, 3D resolution, subtitles on/off, subtitle background, reading time, auto-advance, timing assists, language, reset to defaults. Options apply immediately.
- Rebinding for keyboard and controller, saved with the settings. A conflict inside one mode swaps the two actions.
- Button names for Xbox, PlayStation and Nintendo controllers, detected or chosen in Settings.
- Optional highlight-and-confirm response selection.
- History of lines and chosen responses in the pause menu; rich-text subtitles.
- Recap card waits for the player; Credits card rolls its text.
- Locations load in the background with an indicator; a location that cannot load fails cleanly.
- Episode select for seasons (`user://progress.cfg`).

### Phase 4: localisation
- Every engine string and every content string shown to the player goes through translation.
- `addons/tale_engine/editor/export_strings_cli.tscn` writes a translation template of engine and episode text.
- The Language option appears once a translation is loaded and redraws menus at once.
- A test with a made-up locale fails on any untranslated label.

## Left

### Leftovers from finished phases
| From | Item |
|---|---|
| 1 | `plugin.cfg` and version number for `cinematic_action_director` |
| 1 | Tag `v0.1.0` (or whichever version) on `main` |
| 2 | Replace the remaining private-member access between `Flow`, `TEBalloon`, `TEActionDialogue` and the debug panel with public accessors |
| 3 | Themed UI scenes: the UI is still built in code with fixed sizes, so restyling means editing engine scripts |
| 3 | Save-slot screen showing each slot's details (the data is available from `TESave.info`) |
| 3 | Icon glyphs for controller buttons (prompts use text names) |
| 3 | Skip-already-seen-lines was dropped as untypical for the genre; reopen if wanted |
| 4 | Voice folders per language |
| 4 | Font fallback for non-Latin scripts; layout check for long translations |

### Phase 5: audio
- A bus layout file shipped with the project (buses are currently created at start-up).
- Music and ambience set per step, crossfaded, and restored on resume.
- Pooled sound effects and a positional variant.
- Music behaviour on pause, in menus and on `Flow.stop()`.
- One mouth target per speaker, so barks move the right mouth.

### Phase 6: direction
- A Timeline step that plays an authored `AnimationPlayer` animation with calls for shots, clips, voice, sound and captions, and can be skipped.
- Voice and sound in cutscene cues; waiting for a clip to finish.
- Emotion, gesture, look-at and clip tags in dialogue (`[#emote=]`, `[#gesture=]`, `[#look=]`, `[#clip=]`), with a matching `TEActor` interface and the demo adapter wired to it.
- Mouth movement for rigs without blend shapes (jaw bone).
- More action-prompt assists: auto-complete and hold-toggle.

### Phase 7: exploration
- Camera-relative movement with turn smoothing, and walk/idle animation.
- Follow camera with smoothing and collision.
- Hotspot highlight and facing check; the hint updated on change instead of every frame.
- Examine view.
- A small inventory: declared items, hotspots that need an item, validator coverage.

### Phase 8: editor and authoring tools
- Graph panel: connect and disconnect exits, delete steps, remember node positions, show conditions on edges, undo/redo.
- Validation that does not freeze the editor.
- Validator: more than four responses, bad `#timed` values, missing clip names, parsing dialogue through Dialogue Manager instead of pattern matching.
- A test that pins the numeric value of every enum stored in resources, so reordering one cannot silently change content.

### Phase 9: platform and release engineering
- Linux / Steam Deck export preset; icon, application name and ID.
- Renderer decision (Compatibility versus Mobile or Forward+) and a performance budget measured on Deck-class hardware.
- CI that launches the exported Windows build and plays a route; Linux export boot.
- Platform layer with a Steam backend: achievements and cloud-save paths.
- Crash and log capture.

### Phase 10: hardware sign-off
- A slice episode that ticks every row of the mechanics list. This is written by the game's author, not as part of engine work.
- Full playthrough of the exported build on a Windows PC and a Steam Deck, with physical Xbox and PlayStation controllers ([WINDOWS_SMOKE_TEST.md](WINDOWS_SMOKE_TEST.md)).
- Tag `v1.0.0`.

## Known risks that no phase removes

- Nothing has been run on a physical controller, a real GPU, or as an exported executable. Tests inject input and use the headless renderer. The new menus were checked from 1280×720 captures only.
- The bundled characters have stand-in fight clips and no facial rig. Paired contact animation is content work for each game.
- The rights to the clothing in `addons/narrative_characters` are not recorded; confirm them before shipping a game that includes that addon.
- Dialogue Manager is vendored with local patches (`addons/dialogue_manager/VENDORED.md`); updating it means reapplying them.
- The repository is public. The licence reserves all rights, but the source is visible.

## Picking the work back up

1. Merge any open pull request listed above, then start from `main`.
2. Run `python tools/verify.py --godot <path to Godot 4.6.3>`; it should report 0 failures.
3. Take the next phase from the "Left" section. Each phase is meant to be one pull request, tests first.
4. Update this file and [MECHANICS_TO_TEST.md](MECHANICS_TO_TEST.md) at the end of the phase.
