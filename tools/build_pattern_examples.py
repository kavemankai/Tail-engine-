"""Author native Pattern lab resources. Contains no runtime QTE evaluation."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'content/qte_lab/pattern'


def ext(kind, path, id):
    return f'[ext_resource type="{kind}" path="res://{path}" id="{id}"]\n'


def names(values):
    return 'Array[StringName]([' + ', '.join(f'&"{x}"' for x in values) + '])'


def resource(id, script, fields):
    return f'\n[sub_resource type="Resource" id="{id}"]\nscript = ExtResource("{script}")\n{fields}\n'


def episode(name, compound=False):
    source = ROOT / 'content/qte_lab/direction' / ('counter_episode.tres' if compound else 'choice_episode.tres')
    text = source.read_text().replace('direction/arena.tscn', 'pattern/arena.tscn').replace('DirectionStage', 'PatternStage')
    text = text.replace('direction/counter.template.tres' if compound else 'direction/choice.tres', f'pattern/{name}.tres')
    (DEST / f'{name}_episode.tres').write_text(text)


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    common = ''.join(ext('Script', f'addons/cinematic_action_director/{file}.gd', id) for id, file in [
        ('seq', 'cad_sequence'), ('beat', 'cad_beat'), ('gate', 'cad_gate'), ('option', 'cad_option'), ('spec', 'cad_interaction_spec')])
    for name, steps in [('alternating', ['cad_a', 'cad_b', 'cad_a', 'cad_b']), ('ordered', ['cad_a', 'cad_dodge', 'cad_b'])]:
        text = '[gd_resource type="Resource" script_class="CADSequence" format=3]\n\n' + common
        text += resource('option', 'option', 'id = &"go"\naction = &"cad_a"\nlabel = "' + ('Alternate buttons' if name == 'alternating' else 'Enter the sequence') + '"\nnext = &"action"')
        text += resource('spec', 'spec', f'id = &"{name}"\nfamily = 5\noption_id = &"go"\npattern_steps = {names(steps)}\npattern_deadlines = Array[float]([{", ".join("1.0" for _ in steps)}])\npattern_min_seconds = 0.08\npattern_error = 1')
        text += resource('gate', 'gate', 'options = Array[ExtResource("option")]([SubResource("option")])\ninteraction = SubResource("spec")\nwindow_seconds = 5.0\ntimeout_next = &"recover"')
        for beat, timeline, next in [('input', 'ready', ''), ('action', 'jab', 'completed'), ('recover', 'recover', 'interrupted')]:
            text += resource(beat, 'beat', f'id = &"{beat}"\ntimeline = &"{timeline}"\n' + ('gate = SubResource("gate")' if beat == 'input' else f'next = &"{next}"'))
        text += '\n[resource]\nscript = ExtResource("seq")\nentry = &"input"\nbeats = Array[ExtResource("beat")]([SubResource("input"), SubResource("action"), SubResource("recover")])\noutcomes = Array[StringName]([&"completed", &"interrupted"])\n'
        (DEST / f'{name}.tres').write_text(text)
        episode(name)
    for name, script in [('combo', 'cad_three_punch_template'), ('chain', 'cad_chain_template')]:
        text = '[gd_resource type="Resource" format=3]\n\n' + common + ext('Script', f'addons/cinematic_action_director/compounds/{script}.gd', 'template')
        for i, action in enumerate(['cad_a', 'cad_b', 'cad_a'], start=1):
            text += resource(f'option{i}', 'option', f'id = &"step_{i}"\naction = &"{action}"\nlabel = "' + (f'Punch {i}' if name == 'combo' else ['Attack', 'Block left', 'Counter'][i-1]) + '"')
            fields = f'id = &"{name}_{i}"\noption_id = &"step_{i}"\n'
            fields += 'family = 4\ndirection_mode = 1\nhold_seconds = 0.3\nwrong_input = 1' if name == 'chain' and i == 2 else f'actions = {names([action])}'
            text += resource(f'spec{i}', 'spec', fields)
            text += resource(f'gate{i}', 'gate', f'options = Array[ExtResource("option")]([SubResource("option{i}")])\ninteraction = SubResource("spec{i}")\nwindow_seconds = 1.8')
        text += '\n[resource]\nscript = ExtResource("template")\ngates = Array[ExtResource("gate")]([' + ', '.join(f'SubResource("gate{i}")' for i in range(1,4)) + '])\n'
        text += f'input_timelines = {names(["ready"]*3)}\naction_timelines = {names(["jab", "cross" if name == "combo" else "block", "hook"])}\nrecovery_timelines = {names(["recover"]*3)}\n'
        (DEST / f'{name}.tres').write_text(text)
        episode(name, True)
    # Reuse the stage layout; all movement and cues live in this local library.
    stage = (ROOT / 'content/qte_lab/direction/stage.tscn').read_text().replace('direction/timelines.tres', 'pattern/timelines.tres').replace('DirectionStage', 'PatternStage')
    (DEST / 'stage.tscn').write_text(stage)
    arena = (ROOT / 'content/qte_lab/direction/arena.tscn').read_text().replace('direction/stage.tscn', 'pattern/stage.tscn').replace('Direction', 'Pattern')
    (DEST / 'arena.tscn').write_text(arena)
    clips = {
        'ready': (0.6, True, 'guard', None, 0.0),
        'jab': (0.65, False, 'punch_jab', 'recoil_jab', 0.2),
        'cross': (0.65, False, 'punch_cross', 'recoil_cross', 0.3),
        'hook': (0.8, False, 'punch_hook', 'recoil_hook', 0.25),
        'block': (0.65, False, 'guard', 'windup', 0.0),
        'recover': (0.65, False, 'guard', 'guard', 0.0),
    }
    pieces = ['[gd_resource type="AnimationLibrary" format=3]\n']
    for name, (length, loop, player_clip, npc_clip, lunge) in clips.items():
        pieces.append(f'\n[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = {length}\n')
        if loop:
            pieces.append('loop_mode = 1\n')
        for track, (role, start, contact) in enumerate([('Player', -0.5, -0.5 + lunge), ('Aggressor', 1.2, 1.2 + lunge / 2)]):
            pieces.append(f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{role}:position")\n')
            pieces.append(f'tracks/{track}/keys = {{"times": PackedFloat32Array(0, {length/2}, {length}), "transitions": PackedFloat32Array(1, 1, 1), "update": 0, "values": [Vector3({start}, 0, 0), Vector3({contact}, 0, 0), Vector3({start}, 0, 0)]}}\n')
        calls = [(0, 'cut', ['&"Wide"' if name in ['ready','recover'] else '&"Close"']), (0, 'act', ['&"Player"', f'&"{player_clip}"'])]
        if npc_clip:
            calls.append((length / 2, 'act', ['&"Aggressor"', f'&"{npc_clip}"']))
        for track, (at, method, args) in enumerate(calls, 2):
            pieces.append(f'tracks/{track}/type = "method"\ntracks/{track}/path = NodePath(".")\n')
            pieces.append(f'tracks/{track}/keys = {{"times": PackedFloat32Array({at}), "transitions": PackedFloat32Array(1), "values": [{{"method": &"{method}", "args": [{", ".join(args)}]}}]}}\n')
    pieces.append('\n[resource]\n_data = {\n' + ',\n'.join(f'&"{name}": SubResource("{name}")' for name in clips) + '\n}\n')
    (DEST / 'timelines.tres').write_text(''.join(pieces))


if __name__ == '__main__':
    build()
