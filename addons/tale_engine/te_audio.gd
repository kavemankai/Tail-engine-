extends Node
## Autoload "Audio". One music track with crossfade, plus voice and effects.

var _music: Array[AudioStreamPlayer] = []
var _voice := AudioStreamPlayer.new()
var _active := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_music.append(player)
	add_child(_voice)

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
	_voice.stream = stream
	_voice.play()
	return stream.get_length()

func stop_voice() -> void:
	_voice.stop()

func effect(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
