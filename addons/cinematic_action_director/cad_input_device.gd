class_name CADInputDevice
extends Node
## Autoload InputDevice tracks meaningful input across gameplay modes. The
## director also calls observe(), so CAD still works without the autoload.

signal changed(using_pad: bool)

static var using_pad := false
static var _instance: CADInputDevice

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instance = self

func _input(event: InputEvent) -> void:
	observe(event)

static func observe(event: InputEvent) -> void:
	var next := using_pad
	if event is InputEventJoypadButton and event.pressed:
		next = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		next = true
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		next = false
	set_device(next)

static func set_device(pad: bool) -> void:
	if pad != using_pad:
		using_pad = pad
		if is_instance_valid(_instance):
			_instance.changed.emit(using_pad)

func _exit_tree() -> void:
	_instance = null
