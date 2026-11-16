extends CanvasLayer
## Demonstration host only: resources and the shared Flow/CAD own all QTE logic.

const EPISODE := preload("res://content/qte_lab/episode.tres")
var _box := VBoxContainer.new()
var _summary := Label.new()

func _ready() -> void:
	layer = 60
	_box.position = Vector2(48, 48)
	_box.add_theme_constant_override(&"separation", 16)
	add_child(_box)
	_summary.text = "QTE lab — resource-authored reactions\nGreybox actors; no humanoid contact validation."
	_box.add_child(_summary)
	var start := Button.new()
	start.text = "Play reaction encounter"
	start.pressed.connect(_play)
	_box.add_child(start)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(get_tree().quit)
	_box.add_child(quit)
	start.grab_focus()
	Flow.episode_finished.connect(_on_finished)

func _process(_delta: float) -> void:
	_box.visible = not Flow.running

func _play() -> void:
	Flow.save_slot = -1
	Flow.new_game(EPISODE)

func _on_finished(outcome: StringName) -> void:
	_summary.text = "Outcome: %s\nRetry to compare input and timeout reactions." % outcome
	_box.get_child(1).grab_focus()
