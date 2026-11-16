extends TestSuite
## Story state, conditions and save files.

const EPISODE := preload("res://content/episode_0/episode.tres")

func run() -> void:
	var notices: Array[String] = []
	var listen := func(text: String) -> void: notices.append(text)
	Story.remembered.connect(listen)
	Story.reset(EPISODE.manifest)
	expect(not Story.flag(&"stool_noticed") and Story.vars.size() == 4, "reset loads manifest defaults")
	Story.remember(&"bartender_friendly", true, "The bartender will remember that.")
	Story.put(&"stool_noticed", true)
	expect(Story.flag(&"bartender_friendly") and notices == ["The bartender will remember that."], "remember sets the value and raises the notice")
	Story.choose(&"stranger", &"insult")
	Story.outcomes[&"bar_fight"] = &"won"
	Story.results[&"bar_fight"] = {&"windup": &"dodge"}
	expect(Story.recap() == PackedStringArray(["You insulted the stranger."]), "recap uses the manifest text")

	expect(TECondition.test("bartender_friendly and not insulted_stranger"), "condition reads variables")
	expect(TECondition.test("outcome('bar_fight') == 'won' and result('bar_fight', 'windup') == 'dodge'"), "condition calls Story methods")
	expect(TECondition.test("") and not TECondition.test("insulted_stranger"), "empty is true, false flag is false")
	expect(TECondition.error("no_such_variable", Story.vars) != "", "undeclared variable is reported")
	expect(TECondition.error("stool_noticed and", Story.vars) != "", "syntax error is reported")

	var before := Story.to_dict()
	expect(TESave.write(9, EPISODE.resource_path, [{"step": &"bar_fight", "title": "The fight", "story": before}]), "save written")
	Story.reset()
	var data := TESave.read(9)
	Story.from_dict(data["checkpoints"][0]["story"])
	expect(data["episode"] == EPISODE.resource_path and data["checkpoints"][0]["step"] == &"bar_fight", "save read back")
	expect(Story.flag(&"bartender_friendly") and Story.choices[&"stranger"] == &"insult" and Story.outcome(&"bar_fight") == "won"
		and Story.result(&"bar_fight", &"windup") == "dodge", "story survives a save round trip")
	TESave.erase(9)
	expect(TESave.read(9).is_empty(), "missing save reads as empty")
	Story.remembered.disconnect(listen)
