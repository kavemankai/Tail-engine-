# Verification and the import shutdown leak

Godot is pinned to 4.6.3. `python tools/verify.py --export-windows` runs verbose
editor import, suites, episode validation, Windows export and isolated pack startup.
Script/engine errors and ObjectDB leak warnings remain fatal in every phase.
Linux imports use a temporary XDG configuration/data/cache profile so an existing
Dialogue Manager compiler-version cache cannot hide fresh-install problems.

## Diagnosed failure: run 43836715367

The [failed job](https://github.com/kavemankai/Tail-engine-/actions/runs/43836715367)
stopped at import before any Godot suite or export ran. Python tests passed.
The warning reproduced in **3/3** fresh-checkout, fresh-profile imports locally;
the same Godot binary with an already-used profile did not reproduce it.

Verbose output identified a single `SceneTreeTimer` (reference count 1). A
temporary instrumented copy, with `print_stack()` at reimport scheduling, showed:

```text
DMCache._reimport_when_file_system_is_free
DMCache.reimport_files
DMCache.reimport_all_files
DMImportPlugin._init
DMPlugin._enter_tree
```

On a fresh user profile `compiler_version` is absent. The plugin requests a
reimport while the filesystem scan is busy, then awaits a 0.1-second scene-tree
timer. `--import` can shut down before that callback resumes. This is a plugin
lifecycle issue, not evidence of a gameplay leak or a verified upstream Godot bug.

Local patch: replace that coroutine with a single owned polling `Timer`; stop and
free cache timers from `DMPlugin._exit_tree`. A warm-cache/fresh-profile probe also
exposed the upstream call to the unavailable `EditorFileSystem.is_importing()`;
import activity is now tracked through `resources_reimporting/resources_reimported`.
Polling still waits for the filesystem
and performs queued reimports while the editor is alive. **3/3** equivalent fresh
imports passed without warnings after the patch. The original **169** checks,
episode validation, Windows x86_64 export and isolated resource-pack startup passed.
No warning allowlist or retry-to-green behaviour was added.

To reproduce manually, copy tracked source to a new directory without `.godot/`,
give `XDG_CONFIG_HOME`, `XDG_DATA_HOME` and `XDG_CACHE_HOME` fresh temporary paths,
then run `godot --headless --verbose --editor --path <copy> --import` and inspect
shutdown. Do not delete an existing player's profile to test this.

Windows execution, real-controller behaviour and paired humanoid contact remain
separate hardware/asset gates; cross-export and synthetic events do not prove them.
