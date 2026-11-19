class_name TESmoke
extends Node
## Unattended play-through for exported builds. Start the game with
##   <game> --headless -- --te-smoke
## It plays the title menu's episode (or season) from the start: first
## response at every choice, a hotspot that leaves each hub, every action
## prompt missed. Prints "SMOKE OK" and exits 0 when the episode finishes;
## prints "SMOKE FAILED" and exits 1 on a fault or after LIMIT seconds.
##
## Add --te-perf to measure instead: the route plays at normal speed and the
## frame times are printed as "PERF ..." and written to user://perf.csv. Run it
## on the target hardware (a Steam Deck) with a real window, not --headless.

const LIMIT := 300.0
const SPEED := 4.0

var steps: Array[StringName] = []
## Measuring frame times; plays at normal speed.
var perf := false
var frame_ms: PackedFloat32Array = []
var _left := LIMIT
var _press := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	perf = "--te-perf" in OS.get_cmdline_user_args()
	Engine.time_scale = 1.0 if perf else SPEED
	Settings.text_hold_scale = 0.75
	Settings.choice_time_scale = 0.3
	Flow.save_slot = -1
	Flow.step_started.connect(func(step: TEStep) -> void:
		steps.append(step.id)
		print("SMOKE step %s" % step.id))
	Flow.balloon_opened.connect(func(balloon: TEBalloon) -> void:
		balloon.choices_shown.connect(func(_line: DialogueLine, _responses: Array) -> void: balloon.pick.call_deferred(0)))
	Flow.hub_entered.connect(_explore)
	Flow.episode_finished.connect(func(_exit: StringName) -> void: _end(true, "finished after %d steps" % steps.size()))
	Flow.episode_failed.connect(func(reason: String) -> void: _end(false, reason))
	await get_tree().process_frame
	var menus := get_tree().root.find_children("*", "TETitleMenu", true, false)
	if menus.is_empty():
		_end(false, "no TETitleMenu in the main scene")
		return
	var menu: TETitleMenu = menus[0]
	print("SMOKE start %s on %s" % [ProjectSettings.get_setting("application/config/name"), RenderingServer.get_current_rendering_method()])
	if menu.season != null:
		Flow.start_season(menu.season)
	else:
		Flow.new_game(menu.episode)

## Leave each hub through the first hotspot that can end the step.
func _explore(hub: TEHub) -> void:
	await get_tree().create_timer(0.5).timeout
	for hotspot in hub.hotspots():
		if hotspot.exit != &"" and hub.available(hotspot) and hotspot.unlocked():
			hub.use(hotspot)
			return
	for hotspot in hub.hotspots():
		if hotspot.cue != "" and hub.available(hotspot):
			hub.use(hotspot)
			return

func _process(delta: float) -> void:
	if perf and Flow.running:
		frame_ms.append(delta * 1000.0 / maxf(Engine.time_scale, 0.001))
	_left -= delta / maxf(Engine.time_scale, 0.001)
	if _left <= 0.0:
		_end(false, "timed out after %d s at step %s" % [LIMIT, Flow.step.id if Flow.step != null else &"-"])
		return
	# Move cards and lines on; a timeline asks before skipping, so this also
	# skips timelines after two presses.
	_press -= delta / maxf(Engine.time_scale, 0.001)
	if _press <= 0.0 and not get_tree().paused:
		_press = 0.75
		for pressed: bool in [true, false]:
			var event := InputEventAction.new()
			event.action = &"te_advance"
			event.pressed = pressed
			Input.parse_input_event(event)

## Percentiles of frame time over the route, against a 60 fps budget.
static func frame_summary(samples: PackedFloat32Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return {}
	var at := func(fraction: float) -> float: return sorted[clampi(int(round(fraction * (sorted.size() - 1))), 0, sorted.size() - 1)]
	var over := 0
	for ms in sorted:
		if ms > 1000.0 / 60.0 + 0.5:
			over += 1
	return {"frames": sorted.size(), "p50": at.call(0.5), "p95": at.call(0.95), "p99": at.call(0.99),
		"worst": sorted[-1], "over_budget": float(over) / sorted.size()}

func _report_frames() -> void:
	var summary := frame_summary(frame_ms)
	if summary.is_empty():
		return
	print("PERF frames=%d p50=%.2fms p95=%.2fms p99=%.2fms worst=%.2fms over_16.7ms=%.1f%% renderer=%s adapter=%s" % [
		summary.frames, summary.p50, summary.p95, summary.p99, summary.worst, summary.over_budget * 100.0,
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
	var file := FileAccess.open("user://perf.csv", FileAccess.WRITE)
	if file != null:
		file.store_line("frame,ms")
		for i in frame_ms.size():
			file.store_line("%d,%.3f" % [i, frame_ms[i]])

func _end(ok: bool, detail: String) -> void:
	if not is_inside_tree():
		return
	print("SMOKE %s: %s" % ["OK" if ok else "FAILED", detail])
	if perf:
		_report_frames()
	Engine.time_scale = 1.0
	set_process(false)
	Flow.stop()
	get_tree().quit(0 if ok else 1)
