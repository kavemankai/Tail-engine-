Dialogue Manager v4.2.0, commit bbf9d2a5f6a9eaa276310eea8b1379a936239d2e, from https://github.com/nathanhoad/godot_dialogue_manager (MIT, see LICENSE).

Local lifecycle patch: `DMCache` uses an owned, cancellable node timer for deferred
reimport polling, and `DMPlugin._exit_tree()` disposes its timers. The upstream
SceneTreeTimer coroutine leaked on fresh-profile `--headless --editor --import`
shutdown in Godot 4.6.3. See `docs/VERIFICATION.md` for reproduction and evidence.

The upstream SVG `.import` metadata is included as well as the source assets.
It preserves the UIDs used by editor scripts and scenes on a clean checkout;
`.godot/` remains generated and ignored. Restore these files from the pinned
upstream commit when updating the dependency.
