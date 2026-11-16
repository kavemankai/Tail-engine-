"""Native Pressure/grapple authoring examples; runtime stays in shared handlers."""
from pathlib import Path
from build_pattern_examples import ext, names, resource

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'content/qte_lab/pressure'


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    common = ''.join(ext('Script', f'addons/cinematic_action_director/{file}.gd', id) for id, file in [
        ('seq', 'cad_sequence'), ('beat', 'cad_beat'), ('gate', 'cad_gate'), ('option', 'cad_option'), ('spec', 'cad_interaction_spec')])
    for name in ['pressure', 'grapple']:
        text = '[gd_resource type="Resource" format=3]\n\n' + common
        if name == 'grapple':
            text += ext('Script', 'addons/cinematic_action_director/compounds/cad_grapple_template.gd', 'template')
        steps = ['pressure'] if name == 'pressure' else ['direction', 'pressure', 'release']
        for i, kind in enumerate(steps, 1):
            text += resource(f'option{i}', 'option', f'id = &"{kind}"\naction = &"cad_a"\nlabel = "{kind.title()}"\nnext = &"escape"')
            fields = f'id = &"{name}_{kind}"\noption_id = &"{kind}"\n'
            if kind == 'direction':
                fields += 'family = 4\nwrong_input = 1\n'
            elif kind == 'release':
                fields += f'gesture = 2\nactions = {names(["cad_a"])}\nideal_seconds = 0.6\n'
            else:
                fields += f'family = 7\nactions = {names(["cad_a"])}\n'
                if name == 'pressure':
                    fields += 'routes = Dictionary[StringName, StringName]({&"partial": &"stagger"})\n'
            text += resource(f'spec{i}', 'spec', fields)
            text += resource(f'gate{i}', 'gate', f'options = Array[ExtResource("option")]([SubResource("option{i}")])\ninteraction = SubResource("spec{i}")\nwindow_seconds = 3.0\nopen_marker = &"gate"\ntimeout_next = &"caught"')
        if name == 'grapple':
            text += '\n[resource]\nscript = ExtResource("template")\ngates = Array[ExtResource("gate")]([' + ', '.join(f'SubResource("gate{i}")' for i in range(1,4)) + '])\n'
            text += f'input_timelines = {names(["ready"]*3)}\naction_timelines = {names(["twist", "escape", "release"])}\nrecovery_timelines = {names(["caught"]*3)}\ncompleted_outcome = &"escaped"\ninterrupted_outcome = &"caught"\n'
        else:
            for beat, timeline, next in [('input', 'ready', ''), ('escape', 'escape', 'escaped'), ('stagger', 'stagger', 'staggered'), ('caught', 'caught', 'caught_outcome')]:
                text += resource(beat, 'beat', f'id = &"{beat}"\ntimeline = &"{timeline}"\n' + ('gate = SubResource("gate1")' if beat == 'input' else f'next = &"{next}"'))
            text += '\n[resource]\nscript = ExtResource("seq")\nentry = &"input"\nbeats = Array[ExtResource("beat")]([SubResource("input"), SubResource("escape"), SubResource("stagger"), SubResource("caught")])\noutcomes = Array[StringName]([&"escaped", &"staggered", &"caught_outcome"])\n'
        (DEST / f'{name}.tres').write_text(text)
        episode = (ROOT / 'content/qte_lab/direction' / ('counter_episode.tres' if name == 'grapple' else 'choice_episode.tres')).read_text()
        episode = episode.replace('direction/arena.tscn', 'pressure/arena.tscn').replace('DirectionStage', 'PressureStage').replace('direction/counter.template.tres' if name == 'grapple' else 'direction/choice.tres', f'pressure/{name}.tres')
        (DEST / f'{name}_episode.tres').write_text(episode)
    stage = (ROOT / 'content/qte_lab/direction/stage.tscn').read_text().replace('direction/timelines.tres', 'pressure/timelines.tres').replace('DirectionStage', 'PressureStage')
    (DEST / 'stage.tscn').write_text(stage)
    arena = (ROOT / 'content/qte_lab/direction/arena.tscn').read_text().replace('direction/stage.tscn', 'pressure/stage.tscn').replace('Direction', 'Pressure')
    (DEST / 'arena.tscn').write_text(arena)
    library = ['[gd_resource type="AnimationLibrary" format=3]\n']
    for name in ['ready', 'twist', 'escape', 'release', 'stagger', 'caught']:
        library.append(f'\n[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = 0.6\n')
        if name == 'ready':
            library.append('loop_mode = 1\n')
        for track, role, x in [(0,'Player',-0.5),(1,'Aggressor',1.2)]:
            library.append(f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{role}:position")\ntracks/{track}/keys = {{"times": PackedFloat32Array(0,0.6), "transitions": PackedFloat32Array(1,1), "update": 0, "values": [Vector3({x},0,0),Vector3({x},0,0)]}}\n')
        player = 'grapple_escape' if name in ['escape','release'] else 'grapple_stagger' if name in ['stagger','caught'] else 'grapple_struggle'
        npc = 'grapple_release' if name in ['escape','release'] else 'grapple_struggle'
        calls = [(0,'cut',['&"Wide"' if name == 'ready' else '&"Close"']), (0,'act',['&"Player"',f'&"{player}"']), (0,'act',['&"Aggressor"',f'&"{npc}"'])]
        if name == 'ready':
            calls.append((0.15,'marker',['&"gate"']))
        for track, (at, method, args) in enumerate(calls, 2):
            library.append(f'tracks/{track}/type = "method"\ntracks/{track}/path = NodePath(".")\ntracks/{track}/keys = {{"times": PackedFloat32Array({at}), "transitions": PackedFloat32Array(1), "values": [{{"method": &"{method}", "args": [{", ".join(args)}]}}]}}\n')
    library.append('\n[resource]\n_data = {\n' + ',\n'.join(f'&"{x}": SubResource("{x}")' for x in ['ready','twist','escape','release','stagger','caught']) + '\n}\n')
    (DEST / 'timelines.tres').write_text(''.join(library))


if __name__ == '__main__':
    build()
