"""Author native cinematic/context example. All input/branch logic is shared CAD."""
from pathlib import Path
from build_pattern_examples import ext, names, resource

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'content/qte_lab/cinematic'


def build():
    DEST.mkdir(parents=True, exist_ok=True)
    common = ''.join(ext('Script', f'addons/cinematic_action_director/{file}.gd', id) for id, file in [
        ('seq','cad_sequence'),('beat','cad_beat'),('gate','cad_gate'),('option','cad_option'),('spec','cad_interaction_spec'),('branch','cad_branch'),('predicate','cad_context_predicate')])
    text = '[gd_resource type="Resource" script_class="CADSequence" format=3]\n\n' + common
    for id, action, label, next in [('parry','cad_a','Parry','block'),('restrain','cad_a','Restrain','follow'),('leave','cad_b','Escape','follow')]:
        text += resource(id, 'option', f'id = &"{id}"\naction = &"{action}"\nlabel = "{label}"\nnext = &"{next}"')
    text += resource('parry_spec','spec', f'id = &"opening_parry"\nfamily = 2\noption_id = &"parry"\nactions = {names(["cad_a"])}\nideal_seconds = 0.4\nroutes = Dictionary[StringName,StringName]({{&"partial": &"hit", &"miss": &"hit"}})\nmomentum_changes = Dictionary[StringName,int]({{&"perfect": 2, &"success": 1, &"miss": -1}})')
    text += resource('parry_gate','gate','options = Array[ExtResource("option")]([SubResource("parry")])\ninteraction = SubResource("parry_spec")\nwindow_seconds = 1.5\nopen_marker = &"gate"\ntimeout_next = &"hit"')
    text += resource('decision_spec','spec','id = &"last_chance"\nfamily = 1\noption_intents = Dictionary[StringName,StringName]({&"restrain": &"restrain", &"leave": &"escape"})')
    text += resource('decision_gate','gate','options = Array[ExtResource("option")]([SubResource("restrain"),SubResource("leave")])\ninteraction = SubResource("decision_spec")\nwindow_seconds = 3.0\nopen_marker = &"gate"\ntimeout_next = &"soft"')
    for id, kind, fields, next, requires in [('intent',1,'value = &"escape"','escape',''),('momentum',0,'minimum = 2','condition',''),('actor',2,'subject = &"Player"\nvalue = &"ready"','prop_check',''),('prop',3,'subject = &"bottle"\nexpected = true','strong','stool_noticed')]:
        text += resource(f'predicate_{id}','predicate',f'kind = {kind}\n{fields}')
        text += resource(f'branch_{id}','branch',f'predicate = SubResource("predicate_{id}")\nnext = &"{next}"\nrequires = &"{requires}"')
    beats = [
        ('opening','threat','gate = SubResource("parry_gate")\nplayback_scale = 0.5'),
        ('block','block','next = &"decision"'),
        ('hit','hit','next = &"decision"\nactor_changes = Dictionary[StringName,StringName]({&"Player": &"injured"})'),
        ('decision','question','gate = SubResource("decision_gate")\nplayback_scale = 0.25'),
        ('follow','assess','next = &"strength"\nbranches = Array[ExtResource("branch")]([SubResource("branch_intent")])'),
        ('strength','assess','next = &"soft"\nbranches = Array[ExtResource("branch")]([SubResource("branch_momentum")])'),
        ('condition','assess','next = &"soft"\nbranches = Array[ExtResource("branch")]([SubResource("branch_actor")])'),
        ('prop_check','assess','next = &"soft"\nbranches = Array[ExtResource("branch")]([SubResource("branch_prop")])'),
        ('strong','strong','next = &"restrained"'),('soft','soft','next = &"yielded"'),('escape','escape','next = &"escaped"'),
    ]
    for id,timeline,fields in beats:
        text += resource(id,'beat',f'id = &"{id}"\ntimeline = &"{timeline}"\n{fields}')
    text += '\n[resource]\nscript = ExtResource("seq")\nentry = &"opening"\nbeats = Array[ExtResource("beat")]([' + ','.join(f'SubResource("{id}")' for id,_,_ in beats) + '])\noutcomes = Array[StringName]([&"restrained",&"yielded",&"escaped"])\nactor_statuses = Dictionary[StringName,StringName]({&"Player": &"ready", &"Aggressor": &"ready"})\nprop_states = Dictionary[StringName,bool]({&"bottle": true})\n'
    (DEST/'encounter.tres').write_text(text)
    stage=(ROOT/'content/qte_lab/target/stage.tscn').read_text().replace('target/timelines.tres','cinematic/timelines.tres').replace('TargetStage','CinematicStage')
    stage=stage.replace('[sub_resource type="CylinderMesh"', ext('Script','addons/cinematic_action_director/cad_bark.gd','bark') + '\n[sub_resource type="CylinderMesh"',1)
    stage=stage.replace('[node name="CinematicStage"', '[sub_resource type="Resource" id="question"]\nscript = ExtResource("bark")\nid = &"question"\nspeaker = &"Aggressor"\ntext = "Enough. Will you let me walk away?"\nseconds = 3.5\n\n[node name="CinematicStage"',1)
    stage=stage.replace('target_registry = NodePath("Targets")','target_registry = NodePath("Targets")\nbarks = Array[ExtResource("bark")]([SubResource("question")])',1)
    (DEST/'stage.tscn').write_text(stage)
    arena=(ROOT/'content/qte_lab/target/arena.tscn').read_text().replace('target/stage.tscn','cinematic/stage.tscn').replace('Target','Cinematic')
    (DEST/'arena.tscn').write_text(arena)
    manifest=(ROOT/'content/qte_lab/target/manifest.tres').read_text().replace('&"stool_noticed": false','&"stool_noticed": true')
    (DEST/'manifest.tres').write_text(manifest)
    episode=(ROOT/'content/qte_lab/target/selection_episode.tres').read_text().replace('target/manifest.tres','cinematic/manifest.tres').replace('target/selection.tres','cinematic/encounter.tres').replace('target/arena.tscn','cinematic/arena.tscn').replace('TargetStage','CinematicStage')
    episode=episode.replace('[sub_resource type="Resource" id="exit"]',ext('DialogueResource','content/qte_lab/cinematic/aftermath.dialogue','dialogue')+'\n[sub_resource type="Resource" id="exit"]',1).replace('next = &"END"','next = &"aftermath"',1).replace('id = &"lab"\nkind = 2','id = &"lab"\nkind = 2\ncheckpoint = true',1)
    episode=episode.replace('[resource]\nscript = ExtResource("ep")','''[sub_resource type="Resource" id="after_exit"]
script = ExtResource("exit")
on = &"*"
next = &"checkpoint"

[sub_resource type="Resource" id="after"]
script = ExtResource("step")
id = &"aftermath"
kind = 1
dialogue = ExtResource("dialogue")
cue = "aftermath"
exits = Array[ExtResource("exit")]([SubResource("after_exit")])

[sub_resource type="Resource" id="end_exit"]
script = ExtResource("exit")
on = &"*"
next = &"END"

[sub_resource type="Resource" id="checkpoint"]
script = ExtResource("step")
id = &"checkpoint"
kind = 3
checkpoint = true
heading = "Consequence recorded"
body = "Resume here to keep the decision, or rewind to replay the encounter."
exits = Array[ExtResource("exit")]([SubResource("end_exit")])

[resource]
script = ExtResource("ep")''',1).replace('steps = Array[ExtResource("step")]([SubResource("encounter")])','steps = Array[ExtResource("step")]([SubResource("encounter"),SubResource("after"),SubResource("checkpoint")])')
    (DEST/'episode.tres').write_text(episode)
    (DEST/'aftermath.dialogue').write_text('''~ aftermath
if Story.intent("lab") == "escape"
	stranger: Go. This ends here.
else
	stranger: Fine. No more fighting.
do exit("end")
=> END
''')
    clips = {
        'threat':(0.8,False,[(0,'cut',['&"Wide"']),(0,'act',['&"Aggressor"','&"windup"']),(0.15,'marker',['&"gate"'])]),
        'block':(0.45,False,[(0,'cut',['&"Close"']),(0,'act',['&"Player"','&"guard"'])]),
        'hit':(0.45,False,[(0,'act',['&"Player"','&"hit_react"'])]),
        'question':(0.6,True,[(0,'cut',['&"Wide"']),(0,'bark',['&"question"']),(0.1,'marker',['&"gate"'])]),
        'assess':(0.05,False,[]),
        'strong':(0.6,False,[(0,'cut',['&"Close"']),(0,'act',['&"Player"','&"guard"']),(0.15,'act',['&"Aggressor"','&"guard"'])]),
        'soft':(0.6,False,[(0,'act',['&"Player"','&"guard"']),(0.15,'act',['&"Aggressor"','&"guard"'])]),
        'escape':(0.6,False,[(0,'cut',['&"Wide"']),(0,'act',['&"Player"','&"dodge"'])]),
    }
    library=['[gd_resource type="AnimationLibrary" format=3]\n']
    for name,(length,loop,calls) in clips.items():
        library.append(f'\n[sub_resource type="Animation" id="{name}"]\nresource_name = "{name}"\nlength = {length}\n')
        if loop: library.append('loop_mode = 1\n')
        for track,role,x in [(0,'Player',-0.5),(1,'Aggressor',1.2)]:
            final=x
            if role=='Player' and name in ['escape','soft']: final=-1.5 if name=='escape' else -0.9
            if role=='Aggressor' and name=='strong': final=1.6
            library.append(f'tracks/{track}/type = "value"\ntracks/{track}/path = NodePath("{role}:position")\ntracks/{track}/keys = {{"times": PackedFloat32Array(0,{length}), "transitions": PackedFloat32Array(1,1), "update": 0, "values": [Vector3({x},0,0),Vector3({final},0,0)]}}\n')
        for track,(at,method,args) in enumerate(calls,2):
            library.append(f'tracks/{track}/type = "method"\ntracks/{track}/path = NodePath(".")\ntracks/{track}/keys = {{"times": PackedFloat32Array({at}), "transitions": PackedFloat32Array(1), "values": [{{"method": &"{method}", "args": [{", ".join(args)}]}}]}}\n')
    library.append('\n[resource]\n_data = {\n'+',\n'.join(f'&"{name}": SubResource("{name}")' for name in clips)+'\n}\n')
    (DEST/'timelines.tres').write_text(''.join(library))


if __name__=='__main__': build()
