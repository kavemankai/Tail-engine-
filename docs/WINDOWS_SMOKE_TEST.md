# Last Call — Windows greybox demo

Unzip the entire archive into a writable folder and run `LastCall.exe`. Keep
`LastCall.pck` next to it. This is an unsigned Windows x86_64 greybox build.
Characters and environments are placeholders; dialogue is unvoiced.

## Controls

| Mode | Keyboard | Xbox-style controller |
|---|---|---|
| Menu | Arrows, Enter; Escape/Back in settings | D-pad, A; B/Back in settings |
| Explore | WASD, E interact | Left stick, A interact |
| Dialogue | 1–4 choose, Space advance | Y/B/A/X choose, A advance |
| Action | Space, J, K, W, S as shown | A, X, B, D-pad as shown |
| Pause/resume | Escape | Start |

The title and pause menus both offer Settings. Choices can be untimed; action
prompts can allow up to three times as long. Subtitle size, reading time and
master volume persist across launches. Input prompts follow the last-used
device. Losing window focus pauses gameplay; resume explicitly when ready.

## Release gate: test on an actual Windows PC

Record Windows version, GPU, controller model/connection, build commit and result.
Linux/headless input injection does not substitute for this check.

- Launch from an extracted archive with no Godot editor installed. Check title,
  text layout at 1280×720 and 1920×1080, audio settings and menu navigation.
- Use keyboard and a physical controller. Switch between them during exploration,
  a visible dialogue choice and an action prompt; confirm glyphs update. Test a
  held action, controller disconnect/reconnect and focus loss/return.
- Finish four routes: pay to avoid the fight; notice the stool and win; be kind
  to the bartender and escape the chase; miss prompts and get caught. Confirm
  matching aftermath dialogue and recap choices.
- At each of the bar, stranger, fight and alley checkpoints, quit and relaunch.
  Continue should restart that checkpoint. Rewind to the bar should undo choices.
- Pause/resume and quit during dialogue, an action prompt, exploration, title
  cards and fades. Restart twice. Check for stuck inputs, black screens, old
  prompts, duplicate actors and incorrect camera ownership.
- Change settings through keyboard and controller, relaunch and check persistence.
  Untimed dialogue should wait for input. Larger subtitles should fit the box.
- With the game closed, back up the save and try a truncated slot file. The menu
  should remain usable and omit Continue. Restore the backup afterward.

Saves retain the original application directory for compatibility:
`%APPDATA%\Godot\app_userdata\Cinematic Action Director\`.
Do not distribute player saves with the build.

## Building

Use standard Godot 4.6.3 and its matching export templates (no .NET required).
From the repository root run `python tools/verify.py --export-windows` with
`godot` on PATH, or pass `--godot` with its executable path. The archive is
`build/LastCall-windows-greybox.zip`. Pushes and manual GitHub Actions runs also
produce this artifact after verification; pull requests run checks only.

Automated checks passing means the build is ready for this smoke test. It does
not certify Windows graphics, physical-controller support or signing. The export
runner also starts the resource pack with the host Godot runtime from an empty
directory to catch missing packaged dependencies; that does not run the Windows
executable on a Windows machine.
