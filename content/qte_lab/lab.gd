extends CanvasLayer
## Demonstration host only: resources and the shared Flow/CAD own all QTE logic.

const EPISODE := preload("res://content/qte_lab/episode.tres")
const EXAMPLES := {
	"Reaction press": "res://content/qte_lab/reaction.tres",
	"Hold": "res://content/qte_lab/hold.tres",
	"Timed release": "res://content/qte_lab/release.tres",
	"Simultaneous buttons": "res://content/qte_lab/chord.tres",
	"Graded parry": "res://content/qte_lab/parry.tres",
	"Deliberate restraint": "res://content/qte_lab/restraint.tres",
	"Directional dodge": "res://content/qte_lab/direction/dodge_episode.tres",
	"Directional block": "res://content/qte_lab/direction/block_episode.tres",
	"Directional choice": "res://content/qte_lab/direction/choice_episode.tres",
	"Dodge and counterattack": "res://content/qte_lab/direction/counter_episode.tres",
	"Alternating buttons": "res://content/qte_lab/pattern/alternating_episode.tres",
	"Ordered sequence": "res://content/qte_lab/pattern/ordered_episode.tres",
	"Three-punch combo": "res://content/qte_lab/pattern/combo_episode.tres",
	"Attack / defence chain": "res://content/qte_lab/pattern/chain_episode.tres",
	"Episode 0 — directional variants": "res://content/qte_lab/direction/episode_0_directional.tres",
}
var _box := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _summary := Label.new()
var _last_detail := ""
var _previous_slot := 0

func _ready() -> void:
	_previous_slot = Flow.save_slot
	layer = 60
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 48
	_scroll.offset_top = 48
	_scroll.offset_right = -48
	_scroll.offset_bottom = -48
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box.add_theme_constant_override(&"separation", 12)
	_scroll.add_child(_box)
	_summary.text = "QTE lab — resource-authored reactions\nGreybox actors; no humanoid contact validation."
	_box.add_child(_summary)
	for title: String in EXAMPLES:
		var button := Button.new()
		button.text = title
		button.pressed.connect(_play.bind(EXAMPLES[title]))
		_box.add_child(button)
	var back := Button.new()
	back.text = "Back to Last Call"
	back.pressed.connect(_back)
	_box.add_child(back)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(get_tree().quit)
	_box.add_child(quit)
	_box.get_child(1).grab_focus()
	Flow.episode_finished.connect(_on_finished)
	Flow.director_started.connect(func(director: CADDirector) -> void:
		director.interaction_resolved.connect(func(result: CADResult) -> void:
			_last_detail = "Grade: %s" % result.grade))

func _process(_delta: float) -> void:
	var show_menu := not Flow.running
	if _scroll.visible != show_menu:
		_scroll.visible = show_menu
		if show_menu:
			_box.get_child(1).grab_focus.call_deferred()

func _play(path: String) -> void:
	Flow.save_slot = -1
	_last_detail = ""
	var episode := episode_for(path)
	if episode == null:
		Screen.notice("Could not load this encounter.")
		return
	Flow.new_game(episode)

static func episode_for(path: String) -> TEEpisode:
	var resource := load(path)
	if resource is TEEpisode:
		return resource.duplicate(true)
	if resource is CADSequence:
		var episode: TEEpisode = EPISODE.duplicate(true)
		episode.find(&"lab").sequence = resource
		return episode
	return null

func _on_finished(outcome: StringName) -> void:
	_summary.text = "Outcome: %s   %s\nChoose an encounter to compare reactions." % [outcome, _last_detail]

func _back() -> void:
	Flow.stop()
	Flow.save_slot = _previous_slot
	if get_tree().change_scene_to_file("res://content/main.tscn") != OK:
		Screen.notice("Could not return to Last Call.")
