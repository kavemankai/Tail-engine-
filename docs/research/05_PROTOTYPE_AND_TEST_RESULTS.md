# 05 · Prototype and test results

**Environment:** Linux, Godot `4.6.3.stable.official.7d41c59c4`, GDScript, GL Compatibility project setting. Most assertions ran headlessly with the dummy renderer. Godot enumerated zero physical joypads. The input runs inject native Godot input-event objects through `Input.parse_input_event()`. That validates InputMap and game-side event handling after the device/driver seam.

The package includes `prototype/project.godot`, a runnable two-actor bar exercise, pinned test dependencies, automated audit fixtures and raw logs under `evidence/`. Companion actor assets came from the existing standalone Humanoid Kit. Production checkout and the Conversation Characters Windows folder were unavailable. No production game files were modified.

| Fixture | What ran | Result |
|---|---|---|
| Native scene | Loaded two existing kit actors with female/male variants. Both resolved `GeneralSkeleton` with 65 bones and humanoid hand/foot IDs. Advancing a kit clip changed a real upper-arm bone pose. Native AnimationPlayer method track opened the gate and called kit `Punch_Jab`. Camera cut and prompt visibility observed via viewport and node state. | Keyboard and injected gamepad press each selected `Roll`. No input selected `Hit_Chest`. Outcome signal, same-session state and wide-shot restoration each verified. |
| Event Sequencer upstream demo | Imported and ran pinned checkout as shipped using Godot 4.6.3. | Incomplete demo. Six missing autoload paths across WipeTool, Dialogue Manager, SaveData DX, Sound Manager and CameraAction. Editor logged missing plugins, a root-subfolder error and cleanup warnings. A zero engine exit with these log errors is not a pass. |
| Event Sequencer isolated core | Stock EventNode plus real method/timer/conditional events and a custom awaited event. Serialized a fresh EventNode to a PackedScene and loaded it back from disk. | Generic method invocation started AnimationPlayer and changed from an already-current Camera3D to another. Timer yielded to a later process frame, conditional branch published expected trace, then custom event ran. Fresh dictionary data round-tripped. No claims about editor gesture QA, benchmark throughput or the stock 2D camera adapter. |
| GD-QTE | Original source with fixture bindings and deterministic progress tuning. | Countdown, Timed, Hold and Mash accepted a mapped injected gamepad button. Sequence dropped the same button and accepted a matched keyboard event. Sequence timeout emitted failure twice. Countdown omitted base launch emission and common launch set global time scale to 0.5. These last assertions deliberately confirm defects. |
| Dialogue Manager | Pinned upstream checkout's 4.2.0 plugin version. Compiled a dialogue resource in memory, resolved the initial cue and observed its end, ran both native action outcomes, and retrieved branch-specific resume lines. | Cue-based integration works through the host seam. Legacy Event Sequencer WaitTitle assumes `passed_title`; tested DM has `passed_cue`. The visible packed bar demo uses captions. The DM assertions use the actual addon runtime and do not certify the production balloon or its focus handling. |
| Telltale Explorer | Python module compile/import and empty Chore handle walk. | Smoke only. No original binary or retail asset corpus tested. |
| Other Telltale tooling | Static source audit. | No runtime test for Cutscene Editor (licensed game host unavailable), Telltale Editor (desktop build and Qt stack out of scope) or ToolKit (.NET SDK absent). |

The corrected fixtures run without script errors in their final headless logs. Initial test fixture errors included an inferred Variant failing parse, incorrect `Call Method` parameter names, and a headless wall-time assertion that assumed a minimum real duration for a process-time Timer. The final condition checks that the timer actually yields across process frames. Hold and Mash fixtures were tuned and allowed enough engine ticks. Runtime bugs such as the double timeout remain reproducible with the unmodified addon.

## Reproduce

Extract the zip and open `prototype/project.godot` in Godot 4.6.3. Press F6 with `bar.tscn` open, or F5 to run the project. Let one run time out. Press R or the upper face button (Y on Xbox) to replay, then press Space or the lower face button (A on Xbox) when the compact dodge prompt appears. The prototype input uses basic text rather than device-specific icons. Focus loss stops the exercise at a restart point.

```bash
cd prototype
godot --version
godot --headless --editor --path . --import
for suite in native sequencer qte dialogue; do
    godot --headless --path . res://audit/suite.tscn -- "$suite" --manual-start || exit $?
done
```

In the logs, a PASS for duplicate callbacks, keyboard-only sequence or signal mismatch means the fixture reproduced the finding. It does not mean the dependency met the corresponding product requirement.

## Boundaries and next verification

- Visual fidelity and contact. The kit clips are independently authored. A timed jab, roll and stagger prove playback and switching. They do not guarantee matched hand/torso contact, stance, passing clearance, final root transforms or lip sync. The first production task must measure these with actual encounter clips.
- Graphical launch. An offscreen X11 attempt reached the environment’s display/socket boundary. All functional results below the rendering seam came from the headless runs.
- Hardware. On Windows 4.6.3 use one Xbox-compatible pad and the intended DualSense profile. Check prompt icon family, D-pad and stick direction, pressed-before-open, disconnect, alt-tab, remap and dialogue focus. Repeat with keyboard. Test at 30/60/120 fps and with a frame hitch.
- Production integration. Hook the actual player lock, camera owner, dialogue cue and save service only in an isolated checkout or test integration branch. Validate exact APIs and deployed rig resources before changing the scene. Test flag persistence across save/load and cancellation while the outcome is pending.
- Footage. Stream downloads for the attempted public YouTube captures returned an unavailable response. Directly inspected published Wolf stills and public upload storyboard frames for Batman, The Walking Dead and Tales from the Borderlands. Sample positions and framing evidence are in 04. No onset/expiry timing was claimed from a still or from a successful press. Third-party gameplay images and videos are excluded from the package.
