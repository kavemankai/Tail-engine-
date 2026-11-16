extends TestSuite
## Whole-episode routes, played by the autoplayer.

const EPISODE := preload("res://content/episode_0/episode.tres")

func run() -> void:
	Flow.save_slot = -1
	Settings.text_hold_scale = 0.05
	Settings.choice_time_scale = 0.2
	Engine.time_scale = 4.0

	# Notice the stool, be kind, insult him, then win the fight.
	var player := await play(["kind", "insult"], ["Stool", "Bartender", "Stranger"],
		{&"rush": "cad_dodge", &"counter": "cad_a", &"shove": "hold:cad_a"})
	expect(joined(player.steps) == "title,bar_hub,stranger_talk,bar_fight,aftermath,recap", "route A: steps in order, no chase after a win")
	expect(Story.outcome(&"bar_fight") == "won" and Story.result(&"bar_fight", &"rush") == "dodge",
		"the insult changed the fight's opening beat")
	expect(Story.result(&"bar_fight", &"counter") == "stool", "noticing the stool earlier unlocked the stool option")
	expect("stranger: Alright. Alright. We're square." in player.lines, "aftermath dialogue follows the fight outcome")
	expect(Story.recap() == PackedStringArray(["You were polite to the bartender.", "You insulted the stranger."]), "recap lists the choices made")
	player.free()

	# Rude, refuse, miss every prompt: hit, withdraw, chased and caught.
	player = await play(["rude", "refuse"], ["Bartender", "Stranger"], {})
	expect(joined(player.steps) == "title,bar_hub,stranger_talk,bar_fight,aftermath,alley_chase,caught_talk,recap",
		"route B: losing leads to the alley and getting caught")
	expect(Story.outcome(&"bar_fight") == "withdrew" and Story.result(&"bar_fight", &"windup") == "timeout"
		and Story.outcome(&"alley_chase") == "was_caught", "missed inputs fail forward to the end")
	expect("stranger: This isn't over." in player.lines and "stranger: Told you. Pay it again." in player.lines, "dialogue matches that route")
	player.free()

	# Kind bartender steps in; then escape the chase.
	player = await play(["kind", "refuse"], ["Bartender", "Stranger"],
		{&"windup": "cad_dodge", &"run1": "cad_a", &"run2": "cad_b", &"run3": "cad_up"})
	expect(Story.outcome(&"bar_fight") == "broken_up" and Story.outcome(&"alley_chase") == "escaped"
		and joined(player.steps) == "title,bar_hub,stranger_talk,bar_fight,aftermath,alley_chase,recap",
		"route C: the bartender breaks it up, then a clean escape")
	expect("bartender: Out the back. I never saw you." in player.lines, "the bartender remembered")
	player.free()

	# Pay up: no fight at all.
	player = await play(["pay"], ["Stranger"], {})
	expect(joined(player.steps) == "title,bar_hub,stranger_talk,paid_card,recap", "route D: paying skips the fight")
	player.free()

	# Actors are driven by the stage during an encounter.
	player = AutoPlayer.new()
	player.options = ["refuse"]
	player.hotspots = ["Stranger"]
	player.gates = {&"windup": "cad_dodge"}
	add_child(player)
	Flow.new_game(EPISODE)
	var director: CADDirector = await Flow.director_started
	var opened: Array = await director.gate_opened
	while opened[0].id != &"counter":
		opened = await director.gate_opened
	await frames(2)
	var actor: TEActor = Flow.actors[&"player"]
	expect(actor.global_position.distance_to(Vector3(-1.4, 0, 0)) < 0.05, "cast actor follows its stage slot")
	expect(&"dodge" in actor.clip_log, "timeline clip call reached the actor")
	var finished: Array = []
	Flow.step_finished.connect(func(step: TEStep, exit_name: StringName) -> void: finished.append([step.id, exit_name]), CONNECT_ONE_SHOT)
	Flow.force_exit(&"won")
	expect(finished == [[&"bar_fight", &"won"]], "debug force-exit ends the step with the chosen exit")
	Flow.stop()
	player.free()

	Engine.time_scale = 1.0
	Settings.text_hold_scale = 1.0
	Settings.choice_time_scale = 1.0
	Flow.save_slot = 0

func play(options: Array, hotspots: Array, gates: Dictionary) -> AutoPlayer:
	var player := AutoPlayer.new()
	player.options = options
	player.hotspots = hotspots
	player.gates = gates
	add_child(player)
	Flow.new_game(EPISODE)
	await Flow.episode_finished
	return player
