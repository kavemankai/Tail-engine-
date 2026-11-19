extends Node
## Autoload "Audio". Two looping beds (music and ambience) with crossfades,
## voice with lip-sync, and pooled sound effects, flat or positional.
##
## Buses come from addons/tale_engine/default_bus_layout.tres: Music, SFX,
## Voice, and Ambience, which sends to SFX so the Effects volume covers it.
## A project without the layout still works: missing buses are created.
##
## While the game is paused, music keeps playing a little quieter; ambience,
## effects and voice pause with the scene.

const VOICE_BUS := &"Voice"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const AMBIENCE_BUS := &"Ambience"
const SILENT_DB := -60.0
## How far music drops while the game is paused.
const PAUSE_DUCK_DB := -10.0
const DUCK_SECONDS := 0.25
## Effects that can sound at once, per pool. When all are busy the one that
## started first is cut.
const POOL_SIZE := 12
## Loudness range mapped to mouth 0..1.
const QUIET_DB := -45.0
const LOUD_DB := -8.0
const MOUTH_RISE := 40.0
const MOUTH_FALL := 14.0

## A looping layer that crossfades between two players.
class Bed:
	var players: Array[AudioStreamPlayer] = []
	var active := 0
	## The stream this bed is heading for; null while silent or fading out.
	var stream: AudioStream
	var tween: Tween

	func _init(owner: Node, bus: StringName, keep_playing_when_paused: bool) -> void:
		for i in 2:
			var player := AudioStreamPlayer.new()
			player.bus = bus
			if keep_playing_when_paused:
				player.process_mode = Node.PROCESS_MODE_ALWAYS
			owner.add_child(player)
			players.append(player)

	func fade_to(owner: Node, next: AudioStream, seconds: float, silent_db: float) -> void:
		if next == stream:
			return
		stream = next
		if tween != null and tween.is_valid():
			tween.kill()
		var old := players[active]
		active = 1 - active
		var new := players[active]
		new.stop()
		new.stream = next
		if seconds <= 0.0:
			old.stop()
			new.volume_db = 0.0
			if next != null:
				new.play()
			return
		new.volume_db = silent_db
		if next != null:
			new.play()
		tween = owner.create_tween().set_parallel()
		# Fades finish while the game is paused, so a menu never strands a bed.
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(old, "volume_db", silent_db, seconds)
		if next != null:
			tween.tween_property(new, "volume_db", 0.0, seconds)
		tween.chain().tween_callback(old.stop)

	func sounding() -> AudioStreamPlayer:
		return players[active]

var _music: Bed
var _ambience: Bed
var _voice := AudioStreamPlayer.new()
var _voice_owner: WeakRef
var _voice_priority := 0
var _speaker: WeakRef
var _mouth := 0.0
var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
## Player -> start order, to find the oldest when a pool is full.
var _started: Dictionary = {}
var _start_count := 0
var _duck: AudioEffectAmplify
var _duck_tween: Tween

func _ready() -> void:
	# Pause dialogue audio with the scene tree and its subtitle clock.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for bus: StringName in [MUSIC_BUS, SFX_BUS, VOICE_BUS]:
		Settings.bus_index(bus)
	_ambience_bus()
	_duck = _duck_effect()
	_music = Bed.new(self, MUSIC_BUS, true)
	_ambience = Bed.new(self, AMBIENCE_BUS, false)
	add_child(_voice)
	_voice.bus = VOICE_BUS
	_voice.finished.connect(func() -> void:
		_voice_owner = null
		_voice_priority = 0
		_set_speaker(null))

## Release every stream at shutdown, so quitting mid-fade leaks nothing.
func _exit_tree() -> void:
	for tween: Tween in [_music.tween, _ambience.tween, _duck_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	for player: Node in _music.players + _ambience.players + [_voice] + _flat + _spatial:
		player.stop()
		player.stream = null
	_music.stream = null
	_ambience.stream = null
	_started.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_duck_to(PAUSE_DUCK_DB)
	elif what == NOTIFICATION_UNPAUSED:
		_duck_to(0.0)

func _process(delta: float) -> void:
	var level := 0.0
	if _voice.playing and not _voice.stream_paused:
		level = mouth_level(AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(VOICE_BUS), 0))
	_mouth = smooth_mouth(_mouth, level, delta)
	var actor := speaking_actor()
	if actor != null:
		actor.set_mouth_open(_mouth)

## Map a bus peak (dB) to a 0..1 mouth opening.
static func mouth_level(peak_db: float) -> float:
	return clampf((peak_db - QUIET_DB) / (LOUD_DB - QUIET_DB), 0.0, 1.0)

## Open fast, close slower, so the mouth does not flutter at every sample.
static func smooth_mouth(current: float, target: float, delta: float) -> float:
	var rate := MOUTH_RISE if target > current else MOUTH_FALL
	return move_toward(current, target, rate * delta)

# --- Beds --------------------------------------------------------------------

## Crossfade to a music track. Null fades the music out.
func music(stream: AudioStream, fade: float = 1.0) -> void:
	_music.fade_to(self, stream, fade, SILENT_DB)

## Crossfade to an ambience loop. Null fades it out.
func ambience(stream: AudioStream, fade: float = 1.0) -> void:
	_ambience.fade_to(self, stream, fade, SILENT_DB)

func current_music() -> AudioStream:
	return _music.stream

func current_ambience() -> AudioStream:
	return _ambience.stream

## Fade both beds out, as an episode stops.
func stop_beds(fade: float = 0.6) -> void:
	music(null, fade)
	ambience(null, fade)

## The player currently carrying music; tests and tools read its volume.
func music_player() -> AudioStreamPlayer:
	return _music.sounding()

func ambience_player() -> AudioStreamPlayer:
	return _ambience.sounding()

## Current pause attenuation on the Music bus, in dB (0 when not ducked).
func duck_db() -> float:
	return _duck.volume_db if _duck != null else 0.0

func _duck_to(db: float) -> void:
	if _duck == null:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_property(_duck, "volume_db", db, DUCK_SECONDS)

## The Amplify effect named "Duck" on the Music bus, added if the project's
## bus layout has none.
func _duck_effect() -> AudioEffectAmplify:
	var bus := Settings.bus_index(MUSIC_BUS)
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectAmplify and effect.resource_name == "Duck":
			return effect
	var duck := AudioEffectAmplify.new()
	duck.resource_name = "Duck"
	AudioServer.add_bus_effect(bus, duck)
	return duck

func _ambience_bus() -> void:
	if AudioServer.get_bus_index(AMBIENCE_BUS) < 0:
		var index := Settings.bus_index(AMBIENCE_BUS)
		AudioServer.set_bus_send(index, SFX_BUS)

# --- Effects -----------------------------------------------------------------

## Play a one-shot on the SFX bus. Returns the player used.
func effect(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var player := _take(_flat) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_flat.append(player)
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	_start(player)
	return player

## Play a one-shot at a point in the 3D world, heard from the current camera.
func effect_at(stream: AudioStream, where: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var player := _take(_spatial) as AudioStreamPlayer3D
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.bus = SFX_BUS
		add_child(player)
		_spatial.append(player)
	player.stream = stream
	player.volume_db = volume_db
	player.global_position = where
	_start(player)
	return player

## Effects playing now, flat and positional.
func effects_playing() -> int:
	var count := 0
	for player: Node in _flat + _spatial:
		if player.playing:
			count += 1
	return count

func stop_effects() -> void:
	for player: Node in _flat + _spatial:
		player.stop()

## A free player from the pool, the oldest busy one if the pool is full, or
## null when the pool can still grow.
func _take(pool: Array) -> Node:
	for player: Node in pool:
		if not player.playing:
			return player
	if pool.size() < POOL_SIZE:
		return null
	var oldest: Node = pool[0]
	for player: Node in pool:
		if _started.get(player, 0) < _started.get(oldest, 0):
			oldest = player
	oldest.stop()
	return oldest

func _start(player: Node) -> void:
	_start_count += 1
	_started[player] = _start_count
	player.play()

# --- Voice -------------------------------------------------------------------

## Play a voice line and return its length in seconds. `speaker` is the actor
## whose mouth follows it.
func voice(stream: AudioStream, speaker: TEActor = null) -> float:
	_voice_owner = null
	_voice_priority = 100
	_set_speaker(speaker)
	_voice.stream_paused = false
	_voice.stream = stream
	_voice.play()
	return stream.get_length()

func stop_voice() -> void:
	_voice.stop()
	_voice.stream_paused = false
	_voice_owner = null
	_voice_priority = 0
	_set_speaker(null)

## Barks may replace equal/lower priority voice, never a live dialogue line.
func request_voice(stream: AudioStream, owner: Object, priority: int, speaker: TEActor = null) -> bool:
	if stream == null or not is_instance_valid(owner) or priority < 0 or priority > 90 or (_voice.playing and priority < _voice_priority):
		return false
	_voice_owner = weakref(owner)
	_voice_priority = priority
	_set_speaker(speaker)
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

## The actor whose mouth follows the voice playing now, or null.
func speaking_actor() -> TEActor:
	var actor: Object = _speaker.get_ref() if _speaker != null else null
	return actor as TEActor if is_instance_valid(actor) else null

## Move lip-sync to another actor, closing the previous speaker's mouth.
func _set_speaker(actor: TEActor) -> void:
	var previous := speaking_actor()
	if previous != null and previous != actor:
		previous.set_mouth_open(0.0)
	_speaker = weakref(actor) if actor != null else null
	_mouth = 0.0
