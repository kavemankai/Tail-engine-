# Changelog

## 0.2.0 (unreleased)

- Audio: shipped bus layout; music and ambience per step with crossfades, restored on Continue/Rewind; pooled flat and positional effects; music ducked under the pause menu; lip-sync follows the voice's owner.
- Direction: Timeline step driven by `TETimelineCues` method tracks, skippable; cutscene cues with voice, sound, emotes and clip waits; `[#emote]`, `[#gesture]`, `[#look]`, `[#clip]` dialogue tags; jaw-bone lip-sync fallback; auto-complete and hold-toggle assists.
- Exploration: camera-relative movement, follow camera with smoothing and collision, hotspot facing and highlight, examine view, inventory.
- Editor: graph panel edits exits and steps with undo/redo and kept positions; background validation; validator reads compiled dialogue; enum values pinned by a test.
- Platform: Linux/Steam Deck preset, app name, version and icon, own save folder; `--te-smoke` unattended play of exported builds in verify and CI (including a Windows job); `--te-perf` frame-time probe; `Platform` autoload with local and GodotSteam backends; crash reports.
- Leftovers: `cinematic_action_director` plugin.cfg; public accessors; project theme with font fallback; long-translation layout test; save-slot screen; controller icons on responses; voice folders per language.

## 0.1.x

- Localisation: every engine and content string is translatable, `export_strings_cli.tscn` writes a translation template, and the language option redraws menus live.
- Settings: Music/Effects/Voice volumes, fullscreen, vsync, 3D resolution, subtitles on/off and background, language, auto-advance, reset. Keyboard and controller rebinding. Xbox, PlayStation and Nintendo button names. Highlight-and-confirm responses.
- History of lines in the pause menu, rich-text subtitles, recap that waits for the player, credits card, background location loading with an indicator, episode select, fading notices.
- Proprietary LICENSE added. Unused bar environment (`assets/`, `scenes/`, `scripts/environment/`) removed; exports are about 22 MB smaller.
- Saves: version 2, repair after content patches, rename maps, backups, slot details, season progress kept across restarts.
- Faults stop the episode with `Flow.episode_failed` instead of passing for an ending; wildcard exits no longer match `error` or `cancelled`.
- Losing the controller in use pauses the game. Confirmations before overwriting, rewinding and quitting.
- `tools/new_project.py` keeps Dialogue Manager's SVG import metadata and translation-template settings, and copies the authoring guides into the new project.
- The generator test now imports, validates and boots a generated project in Godot when `GODOT` is set.
- Documentation corrected to match the code; roadmap replaced with the remaining phases to a shippable engine.

## 0.1.0

- Narrative runtime (`tale_engine`): episode step graph, seasons, story state, dialogue balloon with timed choices, hubs, camera director and cutscene steps, checkpoint saves, settings, voice playback, validator, editor graph panel.
- Action layer (`cinematic_action_director`): eight interaction families, five compound templates, barks, scoped slow motion, authoring audit.
- Last Call demo episode and interaction lab, starter template, verification wrapper and CI, Windows export.
