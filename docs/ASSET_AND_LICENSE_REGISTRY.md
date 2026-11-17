# Included third-party material

Tale Engine itself is proprietary; see [LICENSE](../LICENSE). The items below are included under their own terms.

- **Dialogue Manager 4.2.0**, commit `bbf9d2a5f6a9eaa276310eea8b1379a936239d2e`, https://github.com/nathanhoad/godot_dialogue_manager, MIT. Licence is in `addons/dialogue_manager/LICENSE`. Local changes are recorded in `addons/dialogue_manager/VENDORED.md`.
- **Godot Humanoid Kit** (`addons/humanoid_kit`), from `Godot-Humanoid-Kit-Addon.zip`, extracted 15 November 2026. `addons/humanoid_kit/licenses/ASSET_SOURCES.md` records the Quaternius CC0 models and animation sources, source checksums and local processing; the source notices are in the same folder.
- **Narrative Characters** (`addons/narrative_characters`), from `Narrative-Characters-Addon.zip`, integrated 16 November 2026. Body and animation sources are the Quaternius CC0 assets of the Humanoid Kit. The clothing, profiles and procedural conversation layer were created in the supplied package; its own licence document is not in this repository, so the rights to those parts are not recorded here. Confirm them before shipping a game that includes this addon.

Both character addons are optional demo content and are not copied into projects made with `tools/new_project.py`.
