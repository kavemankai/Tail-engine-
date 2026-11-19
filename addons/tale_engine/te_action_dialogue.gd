class_name TEActionDialogue
extends CanvasLayer
## Action subtitles/voice only. Timed responses use CADChoiceHandler, so no
## second confirm listener or dialogue timer competes with the interaction runner.

signal line_shown(cue: CADBark)
signal line_closed
var director: CADDirector
var stage: CADStage
var clock: CADClock
var cue: CADBark
var _duration := 0.0
var _speaker: WeakRef
var _panel := ColorRect.new()
var _name := Label.new()
var _text := Label.new()

func _init() -> void:
	add_child(_panel)
	_panel.add_child(_name)
	_panel.add_child(_text)

func _ready() -> void:
	layer = 45
	clock = CADClock.new(director.clock_source)
	_panel.color = Color(0.05, 0.06, 0.1, 0.85)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 30
	_panel.offset_right = 760
	_panel.offset_top = -145
	_panel.offset_bottom = -30
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.position = Vector2(16, 10)
	_name.add_theme_font_size_override(&"font_size", 20)
	_text.position = Vector2(16, 40)
	_text.size = Vector2(698, 155)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.max_lines_visible = 4
	_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text.add_theme_font_size_override(&"font_size", Settings.subtitle_size)
	_panel.hide()
	stage.bark_requested.connect(_on_bark)
	director.finished.connect(func(_outcome: StringName) -> void: close())
	director.suspension_changed.connect(_suspend)

func _on_bark(value: CADBark, visit: int) -> void:
	if not director.active() or director.stage() != stage or visit != director.visit():
		return
	show_bark(value)

func show_bark(value: CADBark) -> bool:
	if value == null or not value.validation_errors().is_empty() or not director.active() \
			or (cue != null and cue.priority > value.priority):
		return false
	close()
	cue = value.duplicate(true)
	var actor := stage.actor(cue.speaker) as TEActor
	_speaker = weakref(actor) if actor != null else null
	_name.text = tr(actor.character.display_name) if actor != null and actor.character != null else String(cue.speaker)
	_text.text = tr(cue.text)
	var height := _text.get_theme_font(&"font").get_height(Settings.subtitle_size)
	var lines := mini(4, maxi(1, _text.get_line_count()))
	_text.size.y = height * lines + 12
	_panel.offset_top = _panel.offset_bottom - (40 + _text.size.y + 12)
	_duration = cue.seconds
	if cue.voice != null and Audio.request_voice(cue.voice, self, cue.priority, actor):
		_duration = minf(60.0, maxf(_duration, cue.voice.get_length()))
	if actor != null:
		actor.speak(true)
	clock.reset()
	_suspend(director.input_suspended())
	_panel.show()
	line_shown.emit(cue)
	return true

func _process(_delta: float) -> void:
	if cue != null and clock.tick() >= _duration:
		close()

func _suspend(paused: bool) -> void:
	if clock != null:
		clock.set_paused(paused)
	Audio.pause_owned_voice(self, paused)

func close() -> void:
	var was_open := cue != null
	cue = null
	Audio.stop_owned_voice(self)
	var actor: TEActor = _speaker.get_ref() if _speaker != null else null
	if is_instance_valid(actor):
		actor.speak(false)
	_speaker = null
	_panel.hide()
	if was_open:
		line_closed.emit()

func _exit_tree() -> void:
	close()
