"""Rebuild the lab's native AnimationLibrary. Authoring only; no QTE evaluator.

Run from any directory. Actors/props/cameras remain ordinary CADStage slots and
artists can edit the generated library in Godot's Animation panel.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "content/qte_lab/direction"


def vector(value):
    return "Vector3(%s)" % ", ".join(str(x) for x in value)


def build():
    pieces = ['[gd_resource type="AnimationLibrary" format=3]\n']
    p0, n0 = (-0.5, 0, 0), (1.2, 0, 0)
    p1, n1 = (-1.3, 0, 0), (0.3, 0, 0)
    clips = {
        "telegraph": (0.8, False, [p0, p0], [n0, n0], [(0, "cut", ['&"Wide"']), (0, "act", ['&"Aggressor"', '&"windup"']), (0.2, "marker", ['&"gate"'])]),
        "evade": (0.6, False, [p0, p1], [n0, n1], [(0, "cut", ['&"Close"']), (0, "act", ['&"Player"', '&"dodge"'])]),
        "hit": (0.6, False, [p0, (-0.9, 0, 0)], [n0, (0.6, 0, 0)], [(0, "cut", ['&"Close"']), (0.2, "act", ['&"Player"', '&"hit_react"'])]),
        "guard": (0.6, False, [p0, p0], [n0, n0], [(0, "cut", ['&"Close"']), (0, "act", ['&"Player"', '&"guard"'])]),
        "step_right": (0.6, False, [p0, (-0.1, 0, 0)], [n0, n0], [(0, "cut", ['&"Wide"']), (0, "act", ['&"Player"', '&"dodge"'])]),
        "counter_ready": (0.6, True, [p1, p1], [n1, n1], [(0, "cut", ['&"Wide"'])]),
        "counter_land": (0.6, False, [p1, (-0.7, 0, 0), p1], [n1, (0.45, 0, 0), (0.6, 0, 0)], [(0, "cut", ['&"Close"']), (0, "act", ['&"Player"', '&"counter"']), (0.3, "act", ['&"Aggressor"', '&"hit_react"'])]),
        "recover": (0.6, False, [p1, (-1.6, 0, 0)], [n1, n0], [(0, "cut", ['&"Wide"']), (0, "act", ['&"Player"', '&"guard"'])]),
    }
    for name, (length, loop, player, npc, calls) in clips.items():
        pieces.append(f'\n[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = {length}\n')
        if loop:
            pieces.append('loop_mode = 1\n')
        for track, (role, positions) in enumerate([("Player", player), ("Aggressor", npc)]):
            times = [length * index / (len(positions) - 1) for index in range(len(positions))]
            pieces.append(f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{role}:position")\n')
            pieces.append(f'tracks/{track}/keys = {{"times": PackedFloat32Array({", ".join(map(str, times))}), "transitions": PackedFloat32Array({", ".join("1" for _ in times)}), "update": 0, "values": [{", ".join(map(vector, positions))}]}}\n')
        # Separate tracks permit genuinely simultaneous camera/actor cues;
        # duplicate timestamps within one method track replace keys in Godot.
        for track, (time, method, args) in enumerate(calls, start=2):
            pieces.append(f'tracks/{track}/type = "method"\ntracks/{track}/path = NodePath(".")\n')
            pieces.append('tracks/%d/keys = {"times": PackedFloat32Array(%s), "transitions": PackedFloat32Array(1), "values": [{"method": &"%s", "args": [%s]}]}\n' % (
                track, time, method, ", ".join(args)))
    pieces.append('\n[resource]\n_data = {\n' + ',\n'.join(f'&"{name}": SubResource("{name}")' for name in clips) + '\n}\n')
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "timelines.tres").write_text("".join(pieces), encoding="utf-8")


if __name__ == "__main__":
    build()
