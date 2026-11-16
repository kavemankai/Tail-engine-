extends TestSuite
## Conversations: choices, timeouts to silence, story changes and exits.

const EPISODE := preload("res://content/episode_0/episode.tres")
const DIALOGUE := preload("res://content/episode_0/dialogue/episode_0.dialogue")

var pick := ""
var offered := 0
var lines: Array[String] = []

func run() -> void:
	Settings.text_hold_scale = 0.05
	Flow.episode = EPISODE
	Story.reset(EPISODE.manifest)
	var notices: Array[String] = []
	var listen := func(text: String) -> void: notices.append(text)
	Story.remembered.connect(listen)
	Flow.balloon_opened.connect(_on_balloon)

	pick = "kind"
	var exit_name: StringName = await Flow.converse(DIALOGUE, "talk_bartender")
	expect(offered == 3 and exit_name == &"end", "three choices offered, default exit")
	expect(Story.flag(&"bartender_friendly") and Story.choices[&"bartender"] == &"kind" and notices.size() == 1,
		"picked choice changed the story and raised a notice")
	expect(lines == ["bartender: What'll it be?", "bartender: Manners. Rare in here."], "lines shown in order with tags stripped")

	lines.clear()
	offered = 0
	await Flow.converse(DIALOGUE, "talk_bartender")
	expect(offered == 0 and lines == ["bartender: Still here?"], "story state changes the conversation next time")

	pick = ""
	Settings.choice_time_scale = 0.05
	exit_name = await Flow.converse(DIALOGUE, "stranger")
	expect(Story.choices[&"stranger"] == &"silent" and exit_name == &"end", "timed choice ran out and took the silence option")

	pick = "key:te_choice_1"
	Settings.choice_time_scale = 1.0
	exit_name = await Flow.converse(DIALOGUE, "stranger")
	expect(Story.choices[&"stranger"] == &"pay" and exit_name == &"paid", "choice by button press; dialogue named its exit")

	Flow.balloon_opened.disconnect(_on_balloon)
	Story.remembered.disconnect(listen)
	Flow.episode = null
	Settings.text_hold_scale = 1.0

func _on_balloon(balloon: TEBalloon) -> void:
	balloon.line_shown.connect(func(line: DialogueLine) -> void: lines.append("%s: %s" % [line.character, line.text]))
	balloon.choices_shown.connect(func(_line: DialogueLine, responses: Array) -> void:
		offered = responses.size()
		if pick.begins_with("key:"):
			tap(pick.trim_prefix("key:"))
		elif pick != "":
			balloon.pick_option(pick))
