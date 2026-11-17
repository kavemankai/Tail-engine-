"""Author native target/prop lab resources. No scene-local QTE evaluator."""
from pathlib import Path
from build_pattern_examples import ext, names, resource

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'examples/last_call/qte_lab/target'


def build():
    (DEST / 'manifest.tres').write_text((ROOT / 'examples/last_call/episode_0/manifest.tres').read_text().replace('variables = {', 'variables = {\n&"saw_bottle": true,', 1))
    common = ''.join(ext('Script', f'addons/cinematic_action_director/{file}.gd', id) for id, file in [
        ('seq', 'cad_sequence'), ('beat', 'cad_beat'), ('gate', 'cad_gate'), ('option', 'cad_option'), ('spec', 'cad_interaction_spec')])
    for name in ['selection', 'tracking', 'grab']:
        text = '[gd_resource type="Resource" format=3]\n\n' + common
        if name == 'grab':
            text += ext('Script', 'addons/cinematic_action_director/compounds/cad_grab_template.gd', 'template')
        ids = ['bottle', 'crate'] if name == 'selection' else ['moving'] if name == 'tracking' else ['bottle']
        for id in ids:
            text += resource(id, 'option', f'id = &"{id}"\naction = &"cad_a"\nlabel = "{id.title()}"\nnext = &"selected"')
        fields = f'id = &"{name}"\nfamily = 6\ntarget_options = Dictionary[StringName, StringName]({{{", ".join(f"&{chr(34)}{id}{chr(34)}: &{chr(34)}{id}{chr(34)}" for id in ids)}}})\n'
        if name == 'tracking':
            fields += 'target_lock_seconds = 0.6\ntarget_radius = 0.06\n'
        text += resource('spec', 'spec', fields)
        text += resource('gate', 'gate', 'options = Array[ExtResource("option")]([' + ', '.join(f'SubResource("{id}")' for id in ids) + '])\ninteraction = SubResource("spec")\nwindow_seconds = 6.0\ntimeout_next = &"recover"\nopen_marker = &"gate"')
        if name == 'grab':
            text += '\n[resource]\nscript = ExtResource("template")\ngates = Array[ExtResource("gate")]([SubResource("gate")])\n'
            text += f'input_timelines = {names(["ready"])}\naction_timelines = {names(["grab"])}\nrecovery_timelines = {names(["recover"])}\n'
        else:
            for beat, timeline, next in [('input', 'tracking' if name == 'tracking' else 'ready', ''), ('selected', 'selected', 'completed'), ('recover', 'recover', 'interrupted')]:
                text += resource(beat, 'beat', f'id = &"{beat}"\ntimeline = &"{timeline}"\n' + ('gate = SubResource("gate")' if beat == 'input' else f'next = &"{next}"'))
            text += '\n[resource]\nscript = ExtResource("seq")\nentry = &"input"\nbeats = Array[ExtResource("beat")]([SubResource("input"), SubResource("selected"), SubResource("recover")])\noutcomes = Array[StringName]([&"completed", &"interrupted"])\n'
        (DEST / f'{name}.tres').write_text(text)
        source = ROOT / 'examples/last_call/qte_lab/direction' / ('counter_episode.tres' if name == 'grab' else 'choice_episode.tres')
        episode = source.read_text().replace('direction/arena.tscn', 'target/arena.tscn').replace('DirectionStage', 'TargetStage').replace('direction/counter.template.tres' if name == 'grab' else 'direction/choice.tres', f'target/{name}.tres')
        episode = episode.replace('examples/last_call/episode_0/cast.tres', 'examples/last_call/qte_lab/target/cast.tres')
        # Gate eligibility remains read-only and comes from narrative state.
        episode = episode.replace('examples/last_call/episode_0/manifest.tres', 'examples/last_call/qte_lab/target/manifest.tres')
        (DEST / f'{name}_episode.tres').write_text(episode)
    stage = (ROOT / 'examples/last_call/qte_lab/direction/stage.tscn').read_text().replace('direction/timelines.tres', 'target/timelines.tres').replace('DirectionStage', 'TargetStage')
    stage = stage.replace('[node name="TargetStage"', ext('Script', 'addons/cinematic_action_director/cad_target_registry.gd', 'registry') + '\n[sub_resource type="CylinderMesh" id="bottle"]\ntop_radius = 0.06\nbottom_radius = 0.07\nheight = 0.3\n\n[sub_resource type="BoxMesh" id="crate"]\nsize = Vector3(0.3, 0.3, 0.3)\n\n[sub_resource type="SphereMesh" id="orb"]\nradius = 0.12\nheight = 0.24\n\n[node name="TargetStage"',1)
    stage = stage.replace('PackedStringArray("timelines")', 'PackedStringArray("timelines", "target_registry")').replace('timelines = NodePath("Timelines")', 'timelines = NodePath("Timelines")\ntarget_registry = NodePath("Targets")')
    stage += '''
[node name="Targets" type="Node" parent="."]
script = ExtResource("registry")
targets = Dictionary[StringName, NodePath]({&"bottle": NodePath("../Bottle"), &"crate": NodePath("../Crate"), &"moving": NodePath("../Moving")})
labels = Dictionary[StringName, String]({&"bottle": "Bottle", &"crate": "Crate", &"moving": "Moving marker"})
requires = Dictionary[StringName, StringName]({&"bottle": &"saw_bottle"})

[node name="Bottle" type="MeshInstance3D" parent="."]
position = Vector3(-0.15, 1, 0)
mesh = SubResource("bottle")

[node name="Crate" type="MeshInstance3D" parent="."]
position = Vector3(0.8, 0.7, 0)
mesh = SubResource("crate")

[node name="Moving" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.7, 0)
mesh = SubResource("orb")
'''
    (DEST / 'stage.tscn').write_text(stage)
    arena = (ROOT / 'examples/last_call/qte_lab/direction/arena.tscn').read_text().replace('direction/stage.tscn', 'target/stage.tscn').replace('Direction', 'Target')
    (DEST / 'arena.tscn').write_text(arena)
    pieces = ['[gd_resource type="AnimationLibrary" format=3]\n']
    for name in ['ready', 'tracking', 'selected', 'recover', 'grab']:
        length = 1.2 if name in ['tracking','grab'] else 0.6
        pieces.append(f'\n[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = {length}\n')
        if name in ['ready','tracking']:
            pieces.append('loop_mode = 1\n')
        for track, role, positions in [(0, 'Player', [-0.5,-0.5,-0.9,-0.5] if name == 'grab' else [-0.5]*4), (1, 'Aggressor', [1.2]*4)]:
            pieces.append(f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{role}:position")\n')
            pieces.append(f'tracks/{track}/keys = {{"times": PackedFloat32Array(0, {length/6}, {length/2}, {length}), "transitions": PackedFloat32Array(1,1,1,1), "update": 0, "values": [{", ".join(f"Vector3({x},0,0)" for x in positions)}]}}\n')
        calls = [(0, 'cut', ['&"Wide"']), (0, 'act', ['&"Player"', '&"grab"' if name == 'grab' else '&"guard"'])]
        if name in ['ready', 'tracking']:
            calls.append((0.15, 'marker', ['&"gate"']))
        if name == 'grab':
            calls += [(0.2, 'attach_selected_prop', ['&"input_1"', '&"Player"', 'NodePath("HandSocket")']), (0.8, 'detach_selected_prop', ['&"input_1"'])]
        if name == 'tracking':
            pieces.append('tracks/2/type = "value"\ntracks/2/path = NodePath("Moving:position")\ntracks/2/keys = {"times": PackedFloat32Array(0,0.6,1.2), "transitions": PackedFloat32Array(1,1,1), "update": 0, "values": [Vector3(0,1.7,0),Vector3(0.8,1.7,0),Vector3(0,1.7,0)]}\n')
        for track, (at, method, args) in enumerate(calls, 3 if name == 'tracking' else 2):
            pieces.append(f'tracks/{track}/type = "method"\ntracks/{track}/path = NodePath(".")\n')
            pieces.append(f'tracks/{track}/keys = {{"times": PackedFloat32Array({at}), "transitions": PackedFloat32Array(1), "values": [{{"method": &"{method}", "args": [{", ".join(args)}]}}]}}\n')
    pieces.append('\n[resource]\n_data = {\n' + ',\n'.join(f'&"{name}": SubResource("{name}")' for name in ['ready','tracking','selected','recover','grab']) + '\n}\n')
    (DEST / 'timelines.tres').write_text(''.join(pieces))


if __name__ == '__main__':
    build()
