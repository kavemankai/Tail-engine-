extends Node
## Autoload "Audio". One music track with crossfade, plus voice and effects.

var _music: Array[AudioStreamPlayer] = []
var _voice := AudioStreamPlayer.new()
var _active := 0
var _voice_owner: WeakRef
var _voice_priority := 0
## Actor whose mouth follows the voice. Set by Flow as lines are shown.
var mouth_target: TEActor
var _mouth := 0.0

const VOICE_BUS := &"Voice"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
## Loudness range mapped to mouth 0..1.
const QUIET_DB := -45.0
const LOUD_DB := -8.0
const MOUTH_RISE := 40.0
const MOUTH_FALL := 14.0

func _ready() -> void:
	# Pause dialogue audio with the scene tree and its subtitle clock.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i in 2:
		var player := AudioStreamPlayer.new()
		Settings.bus_index(MUSIC_BUS)
		player.bus = MUSIC_BUS
		add_child(player)
		_music.append(player)
	add_child(_voice)
	Settings.bus_index(VOICE_BUS)
	Settings.bus_index(SFX_BUS)
	_voice.bus = VOICE_BUS
	_voice.finished.connect(func() -> void:
		_voice_owner = null
		_voice_priority = 0)

func _process(delta: float) -> void:
	var level := 0.0
	if _voice.playing and not _voice.stream_paused:
		level = mouth_level(AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(VOICE_BUS), 0))
	_mouth = smooth_mouth(_mouth, level, delta)
	if is_instance_valid(mouth_target):
		mouth_target.set_mouth_open(_mouth)

## Map a bus peak (dB) to a 0..1 mouth opening.
static func mouth_level(peak_db: float) -> float:
	return clampf((peak_db - QUIET_DB) / (LOUD_DB - QUIET_DB), 0.0, 1.0)

## Open fast, close slower, so the mouth does not flutter at every sample.
static func smooth_mouth(current: float, target: float, delta: float) -> float:
	var rate := MOUTH_RISE if target > current else MOUTH_FALL
	return move_toward(current, target, rate * delta)

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
	if is_instance_valid(mouth_target):
		mouth_target.set_mouth_open(0.0)
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
	player.bus = SFX_BUS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
