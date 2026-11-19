class_name TEBalloon
extends CanvasLayer
## Plays one Dialogue Manager conversation: subtitles, up to four choices on
## te_choice_1..4, an optional timer, and silence as an answer.
##
## Tags in the dialogue file:
##   line      [#timed=6]     the choices that follow are timed, in seconds
##   line      [#shot=name]   read by Flow to cut the camera
##   response  [#silence]     taken when the timer runs out
##   response  [#opt=name]    a stable name, used by tests and tools
## A dialogue file ends a step with a named exit by calling:  do exit("name")

signal line_shown(line: DialogueLine)
signal choices_shown(line: DialogueLine, responses: Array)
signal finished(exit_name: StringName)

const CHOICE_ACTIONS: Array[StringName] = [&"te_choice_1", &"te_choice_2", &"te_choice_3", &"te_choice_4"]
const DEFAULT_EXIT := &"end"

var cast: TECast
## Character id -> TEActor, so a voiced line moves the speaker's mouth.
var actors: Dictionary = {}

var _exit := DEFAULT_EXIT
var _responses: Array = []
var _picked := -1
var _advance := false
var _panel := ColorRect.new()
var _name := Label.new()
var _text := RichTextLabel.new()
var _more := Label.new()
var _choices := VBoxContainer.new()
var _timer := ProgressBar.new()
var _cancelled := false
var _finished := false

func _ready() -> void:
	layer = 40
	# Dialogue Manager has already translated the line; do not look it up again.
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_panel.color = Color(0.05, 0.06, 0.1, 0.8)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -150
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_name.position = Vector2(60, 14)
	_name.add_theme_font_size_override(&"font_size", 20)
	_panel.add_child(_name)
	_text.position = Vector2(60, 46)
	_text.size = Vector2(1160, 90)
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_text)
	# Shown while a line waits for the player (auto-advance off).
	_more.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_more.position = Vector2(-150, -40)
	_more.add_theme_font_size_override(&"font_size", 18)
	_more.hide()
	_panel.add_child(_more)
	_choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_choices.position = Vector2(60, -330)
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_choices)
	_timer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_timer.offset_top = -160
	_timer.offset_bottom = -152
	_timer.step = 0.0
	_timer.show_percentage = false
	_timer.hide()
	add_child(_timer)
	InputDevice.changed.connect(_refresh_choices)
	Settings.changed.connect(_restyle)
	_restyle()

## Follow the subtitle options, including while a line is on screen.
func _restyle() -> void:
	for size_name: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size"]:
		_text.add_theme_font_size_override(size_name, Settings.subtitle_size)
	_panel.visible = Settings.subtitles
	_panel.color.a = 0.8 if Settings.subtitle_background else 0.0

## Called from dialogue files: the conversation's result for the episode graph.
func exit(exit_name: String) -> void:
	_exit = StringName(exit_name)

func start(resource: DialogueResource, cue: String) -> void:
	if _finished:
		return
	var line: DialogueLine = await resource.get_next_dialogue_line(cue, [self])
	while line != null and not _cancelled:
		_show(line)
		if _cancelled:
			break
		var next_id := line.next_id
		_responses = line.responses.filter(func(response: DialogueResponse) -> bool: return response.is_allowed)
		if _responses.is_empty():
			await _hold(line)
		else:
			var response: DialogueResponse = await _choose(line)
			if response == null:
				break
			next_id = response.next_id
		if _cancelled:
			break
		line = await resource.get_next_dialogue_line(next_id, [self])
	_finish(_exit)

func cancel() -> void:
	_cancelled = true
	_responses = []
	Audio.stop_voice()
	_finish(&"cancelled")

func _finish(exit_name: StringName) -> void:
	if not _finished:
		_finished = true
		_exit = exit_name
		finished.emit(exit_name)

## Pick a response by index, as a button press would.
func pick(index: int) -> void:
	if index >= 0 and index < _responses.size():
		_picked = index

## Pick the response carrying [#opt=name]. False if none is on offer.
func pick_option(option: String) -> bool:
	for i in _responses.size():
		if _responses[i].get_tag_value("opt") == option:
			_picked = i
			return true
	return false

func choosing() -> bool:
	return not _responses.is_empty()

func _show(line: DialogueLine) -> void:
	var character := cast.find(line.character) if cast != null else null
	_name.text = tr(character.display_name) if character != null and character.display_name != "" else line.character
	_name.add_theme_color_override(&"font_color", character.colour if character != null else Color.WHITE)
	_text.text = line.text
	Screen.log_line(_name.text, line.text, character.colour if character != null else Color.WHITE)
	line_shown.emit(line)

func _hold(line: DialogueLine) -> void:
	var seconds := maxf(1.2, line.text.length() * 0.055) * Settings.text_hold_scale
	var stream := _voice_for(line)
	if stream != null:
		seconds = Audio.voice(stream, actors.get(StringName(line.character)) as TEActor)
	_advance = false
	# With auto-advance off the line stays until the player presses advance.
	while (seconds > 0.0 or not Settings.auto_advance) and not _advance and not _cancelled:
		await get_tree().process_frame
		if not get_tree().paused:
			seconds -= get_process_delta_time()
		_more.visible = seconds <= 0.0
		if _more.visible:
			_more.text = "[%s]" % CADPrompt.glyph(&"te_advance", CADInputDevice.using_pad)
	_more.hide()
	if stream != null and not _cancelled:
		Audio.stop_voice()

func _choose(line: DialogueLine) -> DialogueResponse:
	for i in _responses.size():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL if Settings.choice_highlight else Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", 22)
		button.pressed.connect(pick.bind(i))
		_choices.add_child(button)
	_refresh_choices()
	if Settings.choice_highlight and _choices.get_child_count() > 0:
		_choices.get_child(0).grab_focus.call_deferred()
	var window := line.get_tag_value("timed").to_float() * Settings.choice_time_scale
	var left := window
	_timer.visible = window > 0.0
	_timer.max_value = maxf(window, 0.001)
	_picked = -1
	choices_shown.emit(line, _responses)
	while _picked < 0 and not _cancelled:
		await get_tree().process_frame
		if _cancelled:
			return null
		if get_tree().paused:
			continue
		if window > 0.0:
			left -= get_process_delta_time()
			_timer.value = left
			if left <= 0.0 and _picked < 0:
				_picked = 0
				for i in _responses.size():
					if _responses[i].has_tag("silence"):
						_picked = i
	if _cancelled:
		return null
	var chosen: DialogueResponse = _responses[_picked]
	Screen.log_line("", chosen.text, Color(0.75, 0.85, 1.0))
	_responses = []
	_timer.hide()
	for button in _choices.get_children():
		button.queue_free()
	return chosen

func _refresh_choices(_using_pad: bool = false) -> void:
	for i in mini(_choices.get_child_count(), _responses.size()):
		var key := CADPrompt.glyph(CHOICE_ACTIONS[i], CADInputDevice.using_pad) if i < CHOICE_ACTIONS.size() else ""
		# Highlight mode has no per-response button, and a response past the
		# fourth has none either.
		var plain := Settings.choice_highlight or key == ""
		_choices.get_child(i).text = _responses[i].text if plain else "[%s]  %s" % [key, _responses[i].text]

func _input(event: InputEvent) -> void:
	if _cancelled or get_viewport().has_meta(CADDirector.VIEWPORT_OWNER):
		return
	if choosing():
		if Settings.choice_highlight:
			# The focused button takes ui_accept; arrows and the d-pad move focus.
			return
		for i in mini(_responses.size(), CHOICE_ACTIONS.size()):
			if event.is_action_pressed(CHOICE_ACTIONS[i]):
				get_viewport().set_input_as_handled()
				pick(i)
				return
	elif event.is_action_pressed(&"te_advance"):
		get_viewport().set_input_as_handled()
		_advance = true

func _voice_for(line: DialogueLine) -> AudioStream:
	var character := cast.find(line.character) if cast != null else null
	if character == null or character.voice_dir == "" or line.static_id == "":
		return null
	for extension: String in ["ogg", "wav", "mp3"]:
		var path := "%s/%s.%s" % [character.voice_dir, line.static_id, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null
