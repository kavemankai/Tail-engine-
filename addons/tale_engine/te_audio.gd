extends Node
## Autoload "Audio". One music track with crossfade, plus voice and effects.

var _music: Array[AudioStreamPlayer] = []
var _voice := AudioStreamPlayer.new()
var _active := 0
var _voice_owner: WeakRef
var _voice_priority := 0

func _ready() -> void:
	# Pause dialogue audio with the scene tree and its subtitle clock.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_music.append(player)
	add_child(_voice)
	_voice.finished.connect(func() -> void:
		_voice_owner = null
		_voice_priority = 0)

## Crossfade to a track. Null fades the music out.
func music(stream: AudioStream, fade: float = 1.0) -> void:
	var old := _music[_active]
	if old.stream == stream:
		return
	_active = 1 - _active
	var new := _music[_active]
	new.stream = stream
	new.volume_db = -60.0
	if stream != null:
		new.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(old, "volume_db", -60.0, fade)
	tween.tween_property(new, "volume_db", 0.0, fade)
	tween.chain().tween_callback(old.stop)

## Play a voice line and return its length in seconds.
func voice(stream: AudioStream) -> float:
	_voice_owner = null
	_voice_priority = 100
	_voice.stream_paused = false
	_voice.stream = stream
	_voice.play()
	return stream.get_length()

func stop_voice() -> void:
	_voice.stop()
	_voice.stream_paused = false
	_voice_owner = null
	_voice_priority = 0

## Barks may replace equal/lower priority voice, never a live dialogue line.
func request_voice(stream: AudioStream, owner: Object, priority: int) -> bool:
	if stream == null or not is_instance_valid(owner) or priority < 0 or priority > 90 or (_voice.playing and priority < _voice_priority):
		return false
	_voice_owner = weakref(owner)
	_voice_priority = priority
	_voice.stream_paused = false
	_voice.stream = stream
	_voice.play()
	return true

func stop_owned_voice(owner: Object) -> void:
	if _voice_owner != null and _voice_owner.get_ref() == owner:
		stop_voice()

func pause_owned_voice(owner: Object, paused: bool) -> void:
	if _voice_owner != null and _voice_owner.get_ref() == owner:
		_voice.stream_paused = paused

func effect(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
