class_name TETimelineCues
extends Node
## Target for the method tracks of a Timeline step's animation. Put one in the
## location (any name; "Cues" is conventional) and key its methods on a method
## track. Character arguments are cast ids; streams may be given as a resource
## or a res:// path.
##
##   shot("bar_wide", 0.5)               cut, or blend over 0.5 s
##   clip("stranger", "point")           logical clip, mapped by the character
##   voice("stranger", "res://vo/e0_007.ogg")
##   sound("res://sfx/glass.wav")
##   caption("He doesn't look up.")      translated; "" clears it
##   emote("stranger", "angry")
##   gesture("bartender", "shrug")
##   look("stranger", "player")          a cast id, a mark, or "none"
##   shake(0.2)
##   quiet()                             everyone stops talking, voice stops
##
## Calls are ignored while the timeline is being skipped, so a skip never
## fires a burst of voice and sound.

func shot(name: String, blend: float = 0.0) -> void:
	if _live():
		Flow.cut(StringName(name), blend)

func clip(character: String, clip_name: String) -> void:
	var actor := _actor(character)
	if actor != null:
		actor.cad_act(StringName(clip_name))

func voice(character: String, stream: Variant) -> void:
	if not _live():
		return
	var audio := _stream(stream)
	if audio == null:
		push_warning("TETimelineCues: no voice stream at %s." % str(stream))
		return
	var speaker := StringName(character)
	for id: StringName in Flow.actors:
		Flow.actors[id].speak(id == speaker)
	Audio.voice(audio, Flow.actors.get(speaker) as TEActor)

func sound(stream: Variant) -> void:
	if _live():
		Audio.effect(_stream(stream))

func caption(text: String) -> void:
	if _live():
		Screen.caption(text)

func emote(character: String, emotion: String) -> void:
	if _live():
		Flow.direct("emote", StringName(character), emotion)

func gesture(character: String, gesture_name: String) -> void:
	if _live():
		Flow.direct("gesture", StringName(character), gesture_name)

func look(character: String, target: String) -> void:
	if _live():
		Flow.direct("look", StringName(character), target)

func shake(amount: float) -> void:
	if _live():
		Flow.camera.shake(amount)

func quiet() -> void:
	if not _live():
		return
	Audio.stop_voice()
	for actor: TEActor in Flow.actors.values():
		actor.speak(false)

func _live() -> bool:
	return not Flow.timeline_skipping

func _actor(character: String) -> TEActor:
	if not _live():
		return null
	var actor: TEActor = Flow.actors.get(StringName(character))
	if actor == null:
		push_warning("TETimelineCues: '%s' is not in this scene's cast." % character)
	return actor

static func _stream(value: Variant) -> AudioStream:
	if value is AudioStream:
		return value
	if value is String and value != "" and ResourceLoader.exists(value):
		return load(value) as AudioStream
	return null
