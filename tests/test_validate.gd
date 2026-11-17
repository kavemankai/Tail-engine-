extends TestSuite
## The validator passes the real episode and catches seeded mistakes.

const EPISODE := preload("res://examples/last_call/episode_0/episode.tres")

func run() -> void:
	var errors := TEValidator.check(EPISODE)
	for problem in errors:
		print("  ", problem)
	expect(errors.is_empty(), "episode 0 validates clean")
	var coverage := TEValidator.voice_coverage(EPISODE)
	print("  voice lines: %d of %d" % coverage)

	var broken: TEEpisode = EPISODE.duplicate(true)
	broken.find(&"paid_card").exits[0].next = &"nowhere"
	var orphan := TEStep.new()
	orphan.id = &"orphan"
	orphan.kind = TEStep.Kind.CARD
	broken.steps.append(orphan)
	broken.find(&"stranger_talk").cue = "no_such_cue"
	broken.find(&"aftermath").exits[0].when = "outcome('bar_fight') == "
	broken.find(&"bar_fight").roles[&"Ghost"] = &"nobody"
	broken.find(&"alley_chase").cast[&"player"] = "no_such_mark"
	broken.find(&"caught_talk").shot = &"no_such_shot"
	errors = TEValidator.check(broken)
	var text := "\n".join(errors)
	for needle: String in ["missing step 'nowhere'", "missing dialogue cue 'no_such_cue'", "exit condition", "missing stage role 'Ghost'",
			"unknown character 'nobody'", "missing mark 'no_such_mark'", "missing shot 'no_such_shot'", "cannot be reached"]:
		expect(needle in text, "validator reports: " + needle)
