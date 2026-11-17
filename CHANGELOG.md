# Changelog

## Unreleased

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
