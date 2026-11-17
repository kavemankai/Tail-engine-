extends Node
## Autoload "Flow". Walks the episode graph: loads each step's location, places
## its cast, runs the step, and follows the matching exit.

signal step_started(step: TEStep)
signal step_finished(step: TEStep, exit_name: StringName)
signal balloon_opened(balloon: TEBalloon)
signal director_started(director: CADDirector)
signal hub_entered(hub: TEHub)
signal episode_finished(last_exit: StringName)
## The episode stopped because of a fault (missing step, unrouted exit, a step
## that ended with "error"). Never followed by episode_finished.
signal episode_failed(reason: String)
signal _step_done(exit_name: StringName)

const END := &"END"
## Longest a recap stays up if the player does not dismiss it.
const RECAP_SECONDS := 45.0
## A load shorter than this never shows the loading indicator.
const LOADING_GRACE := 0.4
const PLACEHOLDER := preload("res://addons/tale_engine/placeholder_actor.tscn")

var episode: TEEpisode
## The season being played, or null for a standalone episode.
var season: TESeason
var step: TEStep
var location: TELocation
var actors: Dictionary[StringName, TEActor] = {}
## Camera direction: cuts, blends, shake.
var camera := TECamera.new()
## Checkpoints reached this playthrough: { step, title, story }.
var checkpoints: Array = []
var running := false
## True after episode_failed until the next episode or checkpoint starts.
var failed := false
## Seconds played in this save, shown in the slot list.
var playtime := 0.0
## Save slot written at each checkpoint. -1 turns saving off.
var save_slot := 0

var _generation := 0
var _step_token := 0
var _location_path := ""
var _props: Array[Node] = []
## Bounded diagnostic snapshot, separate from saved narrative consequences.
var latest_trace: Dictionary = {}
var _hub: TEHub

func _ready() -> void:
	add_child(camera)
	if OS.is_debug_build():
		add_child(TEDebug.new())

func _process(delta: float) -> void:
	if running:
		playtime += delta

func new_game(new_episode: TEEpisode) -> void:
	playtime = 0.0
	_begin(new_episode, null)

## Start a season at one of its episodes (the first by default).
func start_season(new_season: TESeason, index := 0) -> void:
	if new_season == null or index < 0 or index >= new_season.episodes.size():
		push_error("Flow: season has no episode %d." % index)
		return
	playtime = 0.0
	_begin(new_season.episodes[index], new_season)

## True when the season has an episode after the current one.
func has_next_episode() -> bool:
	return season != null and episode != null and not failed and season.next_after(episode) != null

## Move to the next episode of the season, carrying choices and variables.
## Call after episode_finished. False if there is none.
func next_episode() -> bool:
	if not has_next_episode():
		return false
	var carry := _carry()
	_begin(season.next_after(episode), season, carry[0], carry[1])
	return true

## What the finished episode hands to the next: [carried variables, choice history].
func _carry() -> Array:
	var carried := {}
	for key: StringName in season.carry_variables:
		if Story.vars.has(key):
			carried[key] = Story.vars[key]
	var history: Dictionary = Story.history.duplicate(true)
	history[episode.id] = Story.choices.duplicate()
	return [carried, history]

## Point the save at the start of the next episode, so finishing an episode is
## not lost when the game is closed before "Next episode" is chosen.
func _save_season_progress() -> void:
	if save_slot < 0 or not has_next_episode():
		return
	var next := season.next_after(episode)
	var carry := _carry()
	var vars := {}
	for key in next.manifest.variables:
		vars[StringName(key)] = next.manifest.variables[key]
	for key: StringName in carry[0]:
		if next.manifest.has_variable(key):
			vars[key] = carry[0][key]
	var story := {"vars": vars, "choices": {}, "outcomes": {}, "results": {}, "seen": {}, "history": carry[1]}
	var start := [{"step": next.entry, "title": next.title if next.title != "" else String(next.id), "story": story}]
	if not TESave.write(save_slot, next.resource_path, start,
			{"path": season.resource_path, "index": season.index_of(next)}, {"playtime": playtime}):
		push_warning(TESave.last_error)
		Screen.notice("Could not save your progress. Check available disk space and permissions.")

func _begin(new_episode: TEEpisode, new_season: TESeason, carried := {}, history := {}) -> void:
	stop()
	episode = new_episode
	season = new_season
	checkpoints = []
	Screen.clear_history()
	if season != null:
		TEProgress.mark(season, season.index_of(episode))
	Story.reset(episode.manifest)
	if not carried.is_empty() or not history.is_empty():
		Story.apply_carry(carried, history)
	_play(episode.entry)

## Continue from the newest checkpoint in the save slot. False if there is none.
func resume() -> bool:
	var data := TESave.read(save_slot)
	if data.is_empty() or data["checkpoints"].is_empty() or not ResourceLoader.exists(data["episode"]):
		return false
	stop()
	episode = load(data["episode"])
	season = load(data["season"]["path"]) if data.has("season") else null
	checkpoints = data["checkpoints"]
	playtime = float(data.get("meta", {}).get("playtime", 0.0))
	Screen.clear_history()
	if season != null:
		TEProgress.mark(season, season.index_of(episode))
	var recovered := TESave.last_status == TESave.Status.RECOVERED
	rewind(checkpoints.size() - 1)
	if recovered:
		Screen.notice("Your save was updated to match this version of the game.")
	return true

## Go back to a checkpoint. Later checkpoints are dropped.
func rewind(index: int) -> void:
	if episode == null or index < 0 or index >= checkpoints.size():
		return
	stop()
	checkpoints.resize(index + 1)
	Story.reset(episode.manifest)
	Story.from_dict(checkpoints[index]["story"])
	_play(checkpoints[index]["step"])

func stop() -> void:
	_generation += 1
	_step_token += 1
	_step_done.emit(&"cancelled")
	running = false
	step = null
	camera.stop()
	_clear_props()
	_free_location()
	Audio.stop_voice()
	Screen.clear()

## Run one conversation over the current location. Returns its exit name.
func converse(resource: DialogueResource, cue: String, first_shot: StringName = &"") -> StringName:
	if get_viewport().has_meta(CADDirector.VIEWPORT_OWNER):
		push_warning("Flow: CAD owns action input. Concurrent conversations require a focus coordinator.")
		return &"cancelled"
	var balloon := TEBalloon.new()
	balloon.cast = episode.cast if episode != null else null
	balloon.line_shown.connect(_on_line_shown)
	add_child(balloon)
	_props.append(balloon)
	_cut(first_shot)
	balloon_opened.emit(balloon)
	if not balloon._finished:
		balloon.start(resource, cue)
	if not balloon._finished:
		await balloon.finished
	var exit_name := balloon._exit
	for actor: TEActor in actors.values():
		actor.speak(false)
	_props.erase(balloon)
	balloon.queue_free()
	return exit_name

## Debug: end the current step now with the given exit.
func force_exit(exit_name: StringName) -> void:
	if running and step != null:
		_step_token += 1
		_clear_props()
		Screen.clear()
		_step_done.emit(exit_name)

## Debug: abandon the current step and start another.
func jump(step_id: StringName) -> void:
	if episode != null and episode.find(step_id) != null:
		_generation += 1
		_step_token += 1
		_step_done.emit(&"cancelled")
		_clear_props()
		Screen.clear()
		_play(step_id)

func _play(step_id: StringName) -> void:
	_generation += 1
	var generation := _generation
	running = true
	failed = false
	var last_exit := &""
	var id := step_id
	while id != END:
		step = episode.find(id)
		if step == null:
			_fail("Flow: no step '%s'." % id, generation)
			return
		if step.checkpoint:
			_checkpoint()
		var moved: bool = await _enter_location(step.location, generation)
		if generation != _generation:
			return
		if step.location != "" and location == null:
			_fail("Flow: step '%s' could not load location '%s'." % [step.id, step.location], generation)
			return
		_place_cast()
		if moved or Screen.is_black():
			Screen.fade_in()
		step_started.emit(step)
		if generation != _generation:
			return
		_step_token += 1
		_launch(step, _step_token)
		last_exit = await _step_done
		if generation != _generation:
			return
		Story.outcomes[step.id] = last_exit
		step_finished.emit(step, last_exit)
		if generation != _generation:
			return
		id = step.next_for(last_exit)
		if id == &"":
			_fail("Flow: step '%s' has no exit for '%s'." % [step.id, last_exit], generation)
			return
	running = false
	step = null
	_save_season_progress()
	await Screen.fade_out()
	if generation != _generation:
		return
	_free_location()
	Screen.clear()
	Screen.fade_in()
	episode_finished.emit(last_exit)

## Stop the episode because it cannot continue. The player returns to the menu
## with their last checkpoint intact; the episode is not treated as finished.
func _fail(reason: String, generation: int) -> void:
	TEFault.report(reason)
	running = false
	failed = true
	step = null
	_step_token += 1
	_clear_props()
	await Screen.fade_out()
	if generation != _generation:
		return
	_free_location()
	Screen.clear()
	Screen.fade_in()
	Screen.notice("Something went wrong and this scene could not continue. Your last checkpoint is safe.")
	episode_failed.emit(reason)

func _launch(current: TEStep, token: int) -> void:
	await get_tree().process_frame
	if token != _step_token:
		return
	var exit_name := &"error"
	match current.kind:
		TEStep.Kind.DIALOGUE:
			exit_name = await converse(current.dialogue, current.cue, current.shot)
		TEStep.Kind.ENCOUNTER:
			exit_name = await _encounter(current)
		TEStep.Kind.EXPLORE:
			exit_name = await _explore(current)
		TEStep.Kind.CUTSCENE:
			await _cutscene(current, token)
			exit_name = &"end"
		TEStep.Kind.CARD:
			var body := current.body
			if current.card == TEStep.Card.CREDITS:
				await Screen.credits(current.heading, body)
			elif current.card == TEStep.Card.RECAP:
				# The player's choices stay up until they move on.
				await Screen.card(current.heading, "\n".join(Story.recap()), RECAP_SECONDS, true)
			else:
				await Screen.card(current.heading, body, 3.0)
			exit_name = &"end"
	if token == _step_token:
		_step_done.emit(exit_name)

func _encounter(current: TEStep) -> StringName:
	var sequence := current.resolve_sequence()
	if sequence == null:
		push_error("Flow: step '%s' needs exactly one valid sequence or compound." % current.id)
		return &"error"
	var stage := location.stage(current.stage) if location != null else null
	if stage == null:
		push_error("Flow: step '%s' has no stage '%s'." % [current.id, current.stage])
		return &"error"
	for role: StringName in current.roles:
		if actors.has(current.roles[role]):
			stage.bind(role, actors[current.roles[role]])
	var director := CADDirector.new()
	director.trace.enabled = OS.is_debug_build()
	director.flags = Story.vars
	director.window_scale = Settings.qte_window_scale
	add_child(director)
	_props.append(director)
	var action_dialogue := TEActionDialogue.new()
	action_dialogue.director = director
	action_dialogue.stage = stage
	director.add_child(action_dialogue)
	CADPrompt.bind(director, Screen.prompt_label, Screen.prompt_bar, Screen.prompt_backdrop)
	director.gate_opened.connect(func(beat: CADBeat, options: Array[CADOption], _window: float) -> void:
		Screen.layout_prompt(maxi(2, Screen.prompt_label.text.count("\n") + 1)))
	var outcome := &"error"
	if director.begin(sequence, stage):
		director_started.emit(director)
		outcome = await director.finished if director.active() else director.last_outcome
		latest_trace = director.trace.snapshot()
		if outcome != &"cancelled":
			Story.results[current.id] = director.results.duplicate()
			if outcome in sequence.outcomes and not director.detailed_results.is_empty():
				Story.interactions[current.id] = director.record()
	for role: StringName in current.roles:
		stage.unbind(role)
	_props.erase(director)
	director.queue_free()
	return outcome

func _explore(current: TEStep) -> StringName:
	var hub := location.hub(current.hub) if location != null else null
	if hub == null or not actors.has(episode.player):
		push_error("Flow: step '%s' needs hub '%s' and the player in its cast." % [current.id, current.hub])
		return &"error"
	hub.activate(actors[episode.player], location.zones(), current.id)
	_hub = hub
	hub_entered.emit(hub)
	var exit_name: StringName = await hub.exited if hub.is_processing() else &"cancelled"
	hub.deactivate()
	if _hub == hub:
		_hub = null
	return exit_name

func _checkpoint() -> void:
	var entry := {"step": step.id, "title": step.title if step.title != "" else String(step.id), "story": Story.to_dict()}
	if not checkpoints.is_empty() and checkpoints.back()["step"] == step.id:
		checkpoints[-1] = entry
	else:
		checkpoints.append(entry)
	if save_slot >= 0:
		var season_info := {} if season == null else {"path": season.resource_path, "index": season.index_of(episode)}
		if not TESave.write(save_slot, episode.resource_path, checkpoints, season_info, {"playtime": playtime}):
			push_warning(TESave.last_error)
			Screen.notice("Could not save your progress. Check available disk space and permissions.")

## Returns true when a different location was loaded.
func _enter_location(path: String, generation: int) -> bool:
	if path == "" or (path == _location_path and location != null):
		return false
	await Screen.fade_out()
	if generation != _generation:
		return false
	_free_location()
	var scene := await _load_scene(path)
	if generation != _generation:
		return false
	var root := scene.instantiate() if scene != null else null
	if root is not TELocation:
		if root != null:
			root.free()
		return false
	location = root
	_location_path = path
	add_child(location)
	return true

## Load a scene off the main thread so the game keeps drawing, with a loading
## indicator once it has taken long enough to notice. Null if it cannot load.
func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	if ResourceLoader.has_cached(path) or ResourceLoader.load_threaded_request(path) != OK:
		return load(path) as PackedScene
	var progress: Array = []
	var waited := 0.0
	while ResourceLoader.load_threaded_get_status(path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > LOADING_GRACE:
			Screen.loading(float(progress[0]) if not progress.is_empty() else 0.0)
	Screen.loading(-1.0)
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(path) as PackedScene

func _place_cast() -> void:
	if location == null:
		return
	for id: StringName in step.cast:
		var character := episode.cast.find(id)
		if character == null:
			push_error("Flow: step '%s' casts unknown character '%s'." % [step.id, id])
			continue
		if not actors.has(id):
			var actor: TEActor = (character.actor_scene if character.actor_scene != null else PLACEHOLDER).instantiate()
			actor.setup(character)
			location.add_child(actor)
			actors[id] = actor
		var spot := location.mark(step.cast[id]) if step.cast[id] != "" else null
		if spot != null:
			actors[id].global_transform = spot.global_transform
			actors[id].velocity = Vector3.ZERO
		elif step.cast[id] != "":
			push_error("Flow: step '%s' uses missing mark '%s'." % [step.id, step.cast[id]])

func _on_line_shown(line: DialogueLine) -> void:
	for id: StringName in actors:
		actors[id].speak(id == StringName(line.character))
	Audio.mouth_target = actors.get(StringName(line.character))
	_cut(StringName(line.get_tag_value("shot")), line.get_tag_value("blend").to_float())
	var shake_amount := line.get_tag_value("shake").to_float()
	if shake_amount > 0.0:
		camera.shake(shake_amount)

## Go to Shots/<shot>. A blend above zero moves the camera there instead of cutting.
func _cut(shot: StringName, blend := 0.0) -> void:
	if shot == &"" or location == null:
		return
	var target := location.shot(shot)
	if target != null:
		camera.blend_to(target, blend)
	else:
		push_warning("Flow: location has no shot '%s'." % shot)

func _cutscene(current: TEStep, token: int) -> void:
	for cue in current.cues:
		if token != _step_token:
			return
		_cut(cue.shot, cue.blend)
		if cue.shake > 0.0:
			camera.shake(cue.shake)
		for id: StringName in actors:
			actors[id].speak(id == cue.speaker)
		Audio.mouth_target = actors.get(cue.speaker)
		for id: StringName in cue.clips:
			if actors.has(id):
				actors[id].cad_act(cue.clips[id])
		Screen.caption(cue.caption)
		var seconds := cue.hold * (Settings.text_hold_scale if cue.caption != "" else 1.0)
		await get_tree().create_timer(maxf(seconds, 0.0)).timeout
	if token == _step_token:
		for actor: TEActor in actors.values():
			actor.speak(false)
		Screen.caption("")

func _clear_props() -> void:
	# Cancelling resumes awaiting functions synchronously; detach first so they
	# cannot mutate this iteration or accidentally remove a new session's props.
	var props := _props.duplicate()
	_props.clear()
	var hub := _hub
	_hub = null
	if is_instance_valid(hub):
		hub.cancel()
	for node in props:
		if is_instance_valid(node):
			if node is CADDirector:
				node.cancel()
			elif node is TEBalloon:
				node.cancel()
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				node.queue_free()

func _free_location() -> void:
	actors.clear()
	if is_instance_valid(location):
		remove_child(location)
		location.queue_free()
	location = null
	_location_path = ""

func active_director() -> CADDirector:
	for prop in _props:
		if is_instance_valid(prop) and prop is CADDirector and prop.active():
			return prop
	return null
