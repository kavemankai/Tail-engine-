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
}
var _box := VBoxContainer.new()
var _summary := Label.new()
var _last_detail := ""
var _previous_slot := 0

func _ready() -> void:
	_previous_slot = Flow.save_slot
	layer = 60
	_box.position = Vector2(48, 48)
	_box.add_theme_constant_override(&"separation", 12)
	add_child(_box)
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
	_box.visible = not Flow.running

func _play(path: String) -> void:
	Flow.save_slot = -1
	_last_detail = ""
	var episode: TEEpisode = EPISODE.duplicate(true)
	episode.find(&"lab").sequence = load(path)
	Flow.new_game(episode)

func _on_finished(outcome: StringName) -> void:
	_summary.text = "Outcome: %s   %s\nChoose an encounter to compare reactions." % [outcome, _last_detail]
	_box.get_child(1).grab_focus()

func _back() -> void:
	Flow.stop()
	Flow.save_slot = _previous_slot
	if get_tree().change_scene_to_file("res://content/main.tscn") != OK:
		Screen.notice("Could not return to Last Call.")
