# Platform and release

How a Tale Engine game is exported, checked, measured and shipped on Windows,
Linux and Steam Deck.

## Exports

`export_presets.cfg` has two presets.

| Preset | Output | Notes |
|---|---|---|
| Windows Desktop | `build/windows/LastCall.exe` + `.pck` | x86_64, S3TC/BPTC textures |
| Linux | `build/linux/LastCall.x86_64` + `.pck` | x86_64; this is the Steam Deck build. Feature tag `steamdeck`. |

The exported product is named "Last Call", version 0.2.0, with `icon.svg` as
the window icon. The project's internal name stays `Cinematic Action Director`
so existing saves stay where they are: `%APPDATA%\Godot\app_userdata\Cinematic Action Director`
on Windows and `~/.local/share/godot/app_userdata/Cinematic Action Director` on
Linux. A game made with `tools/new_project.py` is named after its title, which
gives it its own folder. Before a store release, consider
`config/use_custom_user_dir` so saves sit in a folder named for the game rather
than under `Godot/`; changing it moves existing saves.

The Windows `.exe` keeps Godot's icon. Godot sets an `.exe` icon with rcedit,
which runs on Windows, so set `application/icon` to an `.ico` and export there
when the game has real art.

## Smoke runs of the exported build

Every exported build can play its episode unattended:

```
LastCall.x86_64 --headless -- --te-smoke
```

It picks the first response at every choice, leaves each hub through the
first hotspot with an exit, misses every action prompt and presses advance
through cards. It prints `SMOKE OK` and exits 0 when the episode finishes,
or `SMOKE FAILED` and exits 1 on a fault or after five minutes.

| Where | What runs | What it proves |
|---|---|---|
| `python tools/verify.py --export-linux` | Linux export, copied out of the source tree, played headless and then with a window on a virtual display using software OpenGL | Binary, pack, scripts and the Compatibility renderer's shaders all work in an export |
| CI `verify` job on push | the same, plus the Windows export and its pack check | as above |
| CI `windows-smoke` job on push | `LastCall.exe --headless -- --te-smoke` on `windows-latest` | The Windows executable starts and plays the episode |

None of these use a real GPU, a physical controller or a Steam Deck. They
replace none of the hardware checks in [WINDOWS_SMOKE_TEST.md](WINDOWS_SMOKE_TEST.md).

## Renderer

The project uses the **Compatibility** renderer (OpenGL 3.3 / ES 3.0), and
stays on it for now:

- It is the cheapest of Godot's three renderers on GPU time and memory, which
  matters most on a Deck's 15 W APU at 1280×800.
- Its shaders compile quickly, so there are no first-run stutters to hide with
  a shader warm-up step.
- It runs on any PC that can run a game of this kind, and under software GL,
  which is what lets CI play a rendered build.
- A Telltale-style game draws small sets, a few characters and simple
  lighting. It does not need Forward+'s clustered lights, SDFGI or volumetric
  fog.

Switch to Forward+ only if the art direction needs something Compatibility
cannot do: many shadowed lights, global illumination or heavy
post-processing. If you switch, measure again on a Deck, because Forward+
costs several times as much GPU time. Mobile is not worth considering for a
desktop and Deck release.

## Performance budget

The target is a steady 60 fps on Steam Deck at 1280×800 with the default
settings. In frame times, measured over a full route:

| Measure | Budget |
|---|---|
| Median frame | under 12 ms |
| 95th percentile | under 16.7 ms |
| 99th percentile | under 25 ms |
| Frames over 16.7 ms | under 2 % |
| Worst frame outside a location load | under 50 ms |

To measure on a Deck, copy the Linux build over and run it from Desktop Mode
with a window, not headless:

```
./LastCall.x86_64 -- --te-smoke --te-perf
```

The route plays at normal speed. A line like this is printed, and every
frame time goes to `perf.csv` in the save folder:

```
PERF frames=… p50=…ms p95=…ms p99=…ms worst=…ms over_16.7ms=…% renderer=gl_compatibility adapter=…
```

**No Deck figure exists yet.** The same probe on this repository's CI-class
container, using a CPU rasteriser (llvmpipe), gave p50 9.5 ms and p95 57 ms.
That figure tests only that the probe works. It says nothing about a Deck.

If the 3D resolution option is lowered, the 3D view renders below
1280×800 and is upscaled; use it as a fallback setting, not as the budget.

## Steam

`Platform` (an autoload) picks a backend at start-up:

- **Steam**, when the game ships with [GodotSteam](https://godotsteam.com)
  and the Steam client is running. The engine does not include GodotSteam;
  add the GDExtension build to the game project.
- **Local** otherwise. Achievements are kept in `achievements.cfg` in the save
  folder, so they still work in development and DRM-free builds.

Achievements are unlocked by their Steamworks API name, from code or dialogue:

```
do Platform.unlock("paid_the_tab")
```

For development without `steam_appid.txt`, set the project setting
`tale_engine/platform/steam_app_id`.

Cloud saves use Steam Auto-Cloud and need no code. In Steamworks → Steam
Cloud → Root paths, add:

| OS | Root | Subdirectory |
|---|---|---|
| Windows | `WinAppDataRoaming` | `Godot/app_userdata/<config/name>` |
| Linux (and Deck) | `LinuxXdgDataHome` | `godot/app_userdata/<config/name>` |

(or the custom folder, if you set one).

and sync `saves/slot_*.json`, `saves/slot_*.json.bak`, `settings.cfg` and
`progress.cfg` (episode-select progress). Leave out `logs/`, `crash_reports/`
and `session.lock`.

The Steam backend is tested against a stand-in object with GodotSteam's
method names (`steamInitEx`, `setAchievement`, `getAchievement`,
`storeStats`, `run_callbacks`). It has not been run against real Steam.

## Crash and log capture

- Godot writes `logs/godot.log` in the save folder on desktop builds and keeps
  the last few runs.
- `Platform` keeps the latest 200 engine errors and warnings in memory.
- A lock file marks a running session. If it is still there at the next start,
  the last run did not exit cleanly. The previous run's log and recent errors
  are then copied to `crash_reports/report_<time>.txt`, and
  `Platform.last_crash_report` names the file.
- Every fault reported through `TEFault` also writes a report.
- At most ten reports are kept.

Nothing is uploaded. A game that wants crash reports sent home adds that,
with the player's consent, by reading `Platform.reports()`.
