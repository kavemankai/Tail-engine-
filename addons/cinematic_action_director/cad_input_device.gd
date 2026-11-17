class_name CADInputDevice
extends Node
## Autoload InputDevice tracks meaningful input across gameplay modes. The
## director also calls observe(), so CAD still works without the autoload.

signal changed(using_pad: bool)

static var using_pad := false
## Force a naming style ("xbox", "playstation", "nintendo"); empty detects it.
static var style_override := &"":
	set(value):
		if value != style_override:
			style_override = value
			if is_instance_valid(_instance):
				_instance.changed.emit(using_pad)
static var _instance: CADInputDevice
static var _pad_device := 0

## Which family of button names to show for the controller last used.
static func style() -> StringName:
	if style_override != &"":
		return style_override
	return style_of(Input.get_joy_name(_pad_device))

static func style_of(joy_name: String) -> StringName:
	var name := joy_name.to_lower()
	for word: String in ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]:
		if word in name:
			return &"playstation"
	for word: String in ["nintendo", "switch", "joy-con", "joycon"]:
		if word in name:
			return &"nintendo"
	return &"xbox"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_instance = self

func _input(event: InputEvent) -> void:
	observe(event)

static func observe(event: InputEvent) -> void:
	var next := using_pad
	var previous_style := style()
	if event is InputEventJoypadButton and event.pressed:
		next = true
		_pad_device = maxi(event.device, 0)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		next = true
		_pad_device = maxi(event.device, 0)
	elif (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		next = false
	if next == using_pad and next and style() != previous_style and is_instance_valid(_instance):
		_instance.changed.emit(using_pad)
	set_device(next)

static func set_device(pad: bool) -> void:
	if pad != using_pad:
		using_pad = pad
		if is_instance_valid(_instance):
			_instance.changed.emit(using_pad)

func _exit_tree() -> void:
	_instance = null
