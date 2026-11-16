# Authoring an episode

An episode is a folder of data. `content/episode_0` is the working example; copy it to start a new one.

```
episode.tres      the step graph
manifest.tres     story variables and major choices
cast.tres         characters
dialogue/*.dialogue
locations/*.tscn
encounters/<name>/stage.tscn + encounter.tres
```

Point `content/main.gd` at your `episode.tres`. Run `tests/validate.tscn` after every change; it reports missing names before you have to play to find them.

## The step graph

`episode.tres` is a `TEEpisode`: a list of `TEStep` resources and an entry step. Only the graph decides what happens next. Each step runs, ends with a named exit, and the step's `exits` list maps that name to the next step.

| Kind | What runs | What it ends with |
|---|---|---|
| Explore | A hub in the location. The player walks and uses hotspots. | The `exit` of the hotspot that ended it. |
| Dialogue | One cue from a dialogue file. | `end`, or the name passed to `exit("...")` in the file. |
| Encounter | A `CADSequence` on a stage in the location. | The sequence's outcome. |
| Card | A title card, or the recap of choices. | `end`. |

An exit (`TEExit`) has `on` (a name, or `*` for any), an optional `when` condition, and `next` (a step id or `END`). The first match wins, so put conditional exits before the catch-all.

Other step fields:

- `location`: a scene path. Leave empty to stay where you are. Changing it fades out and in.
- `cast`: character id to mark name. Actors are created on first use and stay in the location. An empty mark leaves the actor where it stands.
- `checkpoint`: saves when the step starts. The player can resume or rewind to it. `title` is the name shown in the menu.

A non-interactive cutscene is an Encounter whose sequence has no gates.

## Story state

`manifest.tres` declares every variable with its starting value, and every major choice with one recap sentence per option. Using an undeclared name is an error at validation and at run time.

From a dialogue file:

```
do Story.put("bartender_talked", true)
do Story.remember("bartender_friendly", true, "The bartender will remember that.")
do Story.choose("stranger", "insult")
if Story.flag("stool_noticed")
if Story.outcome("bar_fight") == "won"
```

`remember` with a third argument raises the notice banner. `choose` logs a choice for the recap card. `Story.outcome(step_id)` is how any step ended. `Story.result(step_id, beat_id)` is what the player did at one gate in an encounter: an option id or `timeout`.

## Conditions

One expression language is used for step exits and hotspots. Variables are available by name and `Story` methods can be called:

```
bartender_friendly and not insulted_stranger
outcome('bar_fight') == 'won'
```

Action sequences use plain flag names instead (see below).

## Dialogue files

Standard Dialogue Manager syntax, with these tags:

| Tag | On | Effect |
|---|---|---|
| `[#timed=6]` | the line before responses | The choice has a 6 second timer. |
| `[#silence]` | a response | Taken when the timer runs out. Without one, the first response is taken. |
| `[#shot=name]` | a line | Cuts to that camera in the location. |
| `[#opt=name]` | a response | A stable name for tests and tools. |
| `[ID:e0_001]` | a line | The line's id. Voice files are named after it. |

Speaker names are character ids from the cast. To end a step with a named exit, call `do exit("paid")` before the conversation ends.

A conversation offers up to four responses, on `te_choice_1` to `te_choice_4`.

## Locations

A location scene has a `TELocation` root. The engine finds everything by name:

| Path | Node | Used for |
|---|---|---|
| `Marks/<name>` | `Marker3D` | Where cast members stand. Rotation counts. |
| `Shots/<name>` | `Camera3D` | Dialogue and wide shots. |
| `Hubs/<name>` | `TEHub` | A walk-around area with `TEHotspot` children. |
| `Zones/<name>` | `TECameraZone` with a `Camera3D` child | Optional fixed camera while the player is near. |
| `<name>` | `CADStage` | An encounter stage, instanced as a direct child. |

Floors and walls need collision or the player falls through.

A `TEHotspot` has a verb `label`, a `radius`, and does one or both of: run a `cue` from the hub's dialogue file, and end the step with `exit`. `when` hides it behind a condition. `once` retires it after one use.

## Encounters

Built with the action layer; [INTEGRATION.md](INTEGRATION.md) is the full reference. What matters when it runs inside an episode:

- The step's `stage` names the `CADStage` node in the location, and `roles` maps stage slots to character ids. Those actors follow their slots for the encounter and stay where it leaves them.
- Sequence flags are the story variables. `CADOption.requires = "stool_noticed"` offers an option only if the player looked at the stool earlier. `CADBranch.requires = "insulted_stranger"` sends an ungated beat down a different path. Prefix a name with `!` to require it unset.
- Each gate's result and the outcome are written to `Story` when it ends.
- Start the first timeline with actors where the previous step's marks put them, or they will jump.

## Testing a route

Choose **Interaction lab** on the title menu, or open `content/qte_lab/lab.tscn`.
The reaction, hold, timed-release, chord, parry and restraint `.tres` resources use
the existing bar stage's windup, dodge, hit and back-off timelines. Parry grades
have separately named perfect, success, partial and failure routes. `episode.tres`
binds the normal cast through Flow. No
QTE behaviour lives in the lab script. It disables saves and leaves Episode 0's
original encounters and narrative branches intact. Back to Last Call restores
the normal save slot. See the v2 section in
[INTEGRATION.md](INTEGRATION.md) for spec fields and clock/input policies.

`tests/autoplay.gd` plays an episode from a policy: which `opt` names to pick, which hotspots to visit, which button to press at which beat. `tests/test_flow.gd` shows four routes with assertions on the steps taken and the story state at the end. Add one per ending you care about.

In a debug build, F3 opens a panel with the current step and variables, and buttons to force any exit or jump to any step.
