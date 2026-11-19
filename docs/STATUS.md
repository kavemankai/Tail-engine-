# Status: what is done and what is left

Last updated 19 November 2026.

The goal is an engine a real game can be built and released on, for Windows and Steam Deck. Work was split into ten phases. Phases 0 to 9 are done in code and tests. Phase 10 is sign-off on real hardware, which only a person with the hardware can do.

For a per-mechanic view (what you can author today and how), see [MECHANICS_TO_TEST.md](MECHANICS_TO_TEST.md).

## At a glance

| Phase | Subject | State |
|---|---|---|
| 0 | Mechanics-to-test list | Done (#10) |
| 1 | Legal and repository hygiene | Done (#11, #13); version tag not yet made |
| 2 | Saves and failure handling | Done (#12) |
| 3 | UI, input and settings | Done (#14, #15); layout is still built in code |
| 4 | Localisation | Done (#16) |
| 5 | Audio | Done |
| 6 | Direction (cutscenes and performance) | Done |
| 7 | Exploration | Done |
| 8 | Editor and authoring tools | Done |
| 9 | Platform and release engineering | Done in code; untested on a Deck, a real GPU, real Steam and the Windows CI runner |
| 10 | Hardware sign-off | Not started: needs hardware |

Automated checks: 35 suites, run by `python tools/verify.py` and by CI on every push. `python tools/verify.py --export-linux` also exports the Linux build and plays Episode 0 with the exported binary, headless and with software-rendered OpenGL.

## Done in phases 5 to 9, and the leftovers

### Phase 5: audio
- `addons/tale_engine/default_bus_layout.tres`: Music (with a pause duck), SFX, Voice, Ambience (feeding SFX).
- Music and ambience per step with crossfades; checkpoints record them and Continue/Rewind restore them; the episode ending, failing or stopping fades them out. Title menu music.
- Pooled flat and positional effects (`Audio.effect`, `Audio.effect_at`), twelve of each.
- Music plays on, ducked, under the pause menu; ambience, effects and voice pause.
- Lip-sync follows whoever owns the voice playing now, so barks move the right mouth.

### Phase 6: direction
- Timeline step: an authored `AnimationPlayer` animation whose method tracks call `TETimelineCues` (shot, clip, voice, sound, caption, emote, gesture, look, shake, quiet). Skippable with two presses; a skip fires none of the remaining cues.
- Cutscene cues gain voice, sound, emotes and waiting for a clip to finish.
- Dialogue tags `[#emote=]`, `[#gesture=]`, `[#look=]`, `[#clip=]`, optionally naming another character.
- `TEActor` gains `emote`, `gesture`, `look_at_point`, `clear_look`, `clip_playing`, `locomotion`, and a jaw-bone fallback for lip-sync. The Last Call adapter maps them onto the character kit.
- Action prompt assists: auto-complete for skill prompts (choices still wait) and hold-toggle.

### Phase 7: exploration
- Camera-relative movement that keeps its direction across a camera cut while the stick is held; bounded turn speed; walk/idle through `locomotion`.
- Follow camera with smoothing and wall collision.
- Hotspot facing check and highlight; the hint is written only when it changes.
- Examine view.
- Inventory: declared items, `give`/`take`/`has_item`, saved and repaired after patches, hotspots that need or use up an item, validator coverage.

### Phase 8: editor and authoring tools
- Graph panel: connect and disconnect exits, add exits, delete steps, kept node positions, conditions on exit rows, undo/redo through `TEGraphEdit`.
- Validation runs on a worker thread.
- Validator reads Dialogue Manager's compiled lines: speakers, choices of more than four responses, bad `#timed`, `#clip` names missing from a clip map (also in cutscene cues), timeline cue calls.
- A test pins every enum value stored in resources.

### Phase 9: platform and release engineering
- Linux preset (the Steam Deck build); exported product name "Last Call", version 0.2.0, icon. The internal project name is unchanged so existing saves stay put.
- Renderer decision (stay on Compatibility) and a 60 fps budget for the Deck, with a frame-time probe (`--te-smoke --te-perf`). See [PLATFORM.md](PLATFORM.md).
- `--te-smoke` plays the episode unattended in any exported build. Verify and CI play the exported Linux build headless and rendered; a new CI job runs the Windows `.exe` on `windows-latest`.
- `Platform` autoload with a local backend and a Steam backend for GodotSteam: achievements, save directory, Steam language.
- Crash and log capture: recent engine errors kept in memory, a report when the last run did not exit cleanly, a report for every fault.

### Leftovers from phases 1 to 4
- `plugin.cfg` and version 0.2.0 for `cinematic_action_director`.
- Flow, the debug panel and action subtitles use public accessors on `TEBalloon` and `CADDirector`; a test checks for private access.
- The project theme (`addons/tale_engine/ui/tale_theme.tres`, set as `gui/theme/custom`) carries the fonts; a game restyles by swapping it.
- Font fallback for Arabic, Hebrew, Thai, Devanagari and CJK through system fonts; a test grows every string by half and checks Settings and the pause menu still fit.
- Save-slot screen showing each slot's checkpoint, date and time played.
- Controller button icons (Xbox, PlayStation, Nintendo) on dialogue response buttons.
- Voice folders per language.

## Left

### Not done, by decision or because it needs you
| Item | Why it is open |
|---|---|
| Tag `v0.1.0` / `v0.2.0` on `main` | A release decision; tag after merging. |
| Phase 10: a slice episode that ticks every row of the mechanics list | Written by the game's author. |
| Phase 10: playthrough of the exported build on a Windows PC and a Steam Deck with physical Xbox and PlayStation controllers | Needs the hardware; see [WINDOWS_SMOKE_TEST.md](WINDOWS_SMOKE_TEST.md). |
| Deck frame-time figures against the budget | Run `--te-smoke --te-perf` on a Deck. |
| Steam backend against real Steam | Needs GodotSteam in the project and a Steamworks app id. |
| The `windows-smoke` CI job | Written, not yet run: it runs on the first push to GitHub after this change. |
| Skip-already-seen lines | Dropped as untypical for the genre; reopen if wanted. |

### Partly done
| Item | What is missing |
|---|---|
| Themed UI | Fonts and widget styles come from the theme. Positions and sizes of the subtitle panel, menus and prompts are still set in code. |
| Controller icons | On dialogue responses only. Hub hints and action prompts still use button names. |
| Right-to-left languages | Arabic and Hebrew text gets a font, but layouts are not mirrored. |
| Lip-sync with a jaw bone | An animation that also keys the jaw overrides it. |
| Windows `.exe` icon | Needs an `.ico` and an export on Windows (rcedit). |

## Known risks that no phase removes

- Nothing has been played on a physical controller, a real GPU or a Steam Deck. The exported Linux binary has been run headless and with software OpenGL; that proves the export, not the hardware.
- The bundled characters have stand-in fight clips and no facial rig. Paired contact animation is content work for each game.
- The rights to the clothing in `addons/narrative_characters` are not recorded; confirm them before shipping a game that includes that addon.
- Dialogue Manager is vendored with local patches (`addons/dialogue_manager/VENDORED.md`); updating it means reapplying them.
- The repository is public. The licence reserves all rights, but the source is visible.

## Picking the work back up

1. Merge the open pull request, then start from `main`.
2. Run `python tools/verify.py --export-linux --godot <path to Godot 4.6.3>`; it should report 0 failures and `SMOKE OK` twice.
3. Do phase 10 on hardware. File what breaks as issues; each fix gets a test.
