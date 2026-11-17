extends Node
## Autoload "Settings". Player options, stored in user://settings.cfg.
## Every option is a property here with its default in DEFAULTS; numeric ones
## also have a range in LIMITS. Input bindings live in the same file.

## Emitted after any option is applied, so open UI can restyle itself.
signal changed

const PATH := "user://settings.cfg"
const LIMITS := {
	"qte_window_scale": Vector2(1.0, 3.0),
	"choice_time_scale": Vector2(0.0, 3.0),
	"text_hold_scale": Vector2(0.75, 2.0),
	"subtitle_size": Vector2(20, 36),
	"master_volume": Vector2(0, 1),
	"music_volume": Vector2(0, 1),
	"sfx_volume": Vector2(0, 1),
	"voice_volume": Vector2(0, 1),
	"render_scale": Vector2(0.5, 1.0),
}
const DEFAULTS := {
	"qte_window_scale": 1.0,
	"choice_time_scale": 1.0,
	"text_hold_scale": 1.0,
	"subtitle_size": 24,
	"master_volume": 1.0,
	"music_volume": 1.0,
	"sfx_volume": 1.0,
	"voice_volume": 1.0,
	"render_scale": 1.0,
	"subtitles": true,
	"subtitle_background": true,
	"choice_highlight": false,
	"auto_advance": true,
	"fullscreen": false,
	"vsync": true,
	"language": "",
	"prompt_style": "",
}
## Volume setting -> audio bus. Missing buses are created, sending to Master.
const BUSES := {
	"master_volume": &"Master",
	"music_volume": &"Music",
	"sfx_volume": &"SFX",
	"voice_volume": &"Voice",
}

## Multiplies every QTE window. Above 1 gives more time.
var qte_window_scale := 1.0
## Multiplies timed-choice windows. Zero removes the timer.
var choice_time_scale := 1.0
## Multiplies how long an unvoiced line stays up.
var text_hold_scale := 1.0
var subtitle_size := 24
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var voice_volume := 1.0
## 3D resolution as a fraction of the window. Lower is faster.
var render_scale := 1.0
## Show spoken lines and captions as text. Choices are always shown.
var subtitles := true
## Dark panel behind subtitles.
var subtitle_background := true
## Choose dialogue responses by moving a highlight and confirming, instead of
## one button per response. Also reaches a fifth response and beyond.
var choice_highlight := false
## Lines move on by themselves after their reading time. Off waits for a press.
var auto_advance := true
var fullscreen := false
var vsync := true
## Locale code such as "fr"; empty follows the system language.
var language := ""
## Controller button names: "" detects from the pad, or "xbox", "playstation", "nintendo".
var prompt_style := ""
var _language_set := false

func _ready() -> void:
	TEBindings.capture_defaults()
	reload()

func reload() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in DEFAULTS:
			_accept(key, config.get_value("settings", key, get(key)))
		TEBindings.restore(config.get_value("input", "bindings", {}))
	apply()

## Assign a value if it has the right type, clamped to its range.
func _accept(key: String, value: Variant) -> void:
	var fallback: Variant = DEFAULTS[key]
	if fallback is bool:
		if value is bool:
			set(key, value)
	elif fallback is String:
		if value is String and value.length() <= 16:
			set(key, value)
	elif (value is int or value is float) and is_finite(float(value)):
		var clamped := clampf(value, LIMITS[key].x, LIMITS[key].y)
		set(key, int(clamped) if fallback is int else clamped)

func apply() -> void:
	for key: String in BUSES:
		AudioServer.set_bus_volume_db(bus_index(BUSES[key]), linear_to_db(maxf(get(key), 0.0001)))
	CADInputDevice.style_override = StringName(prompt_style)
	if language != "" and language in TranslationServer.get_loaded_locales():
		TranslationServer.set_locale(language)
		_language_set = true
	elif _language_set:
		TranslationServer.set_locale(OS.get_locale())
		_language_set = false
	_apply_display()
	changed.emit()

## Index of a named bus, creating it (sending to Master) if the project has none.
static func bus_index(bus: StringName) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	return index

func _apply_display() -> void:
	get_viewport().scaling_3d_scale = render_scale
	# There is no window to change when running headless or embedded in the editor.
	if DisplayServer.get_name() == "headless" or Engine.is_embedded_in_editor():
		return
	var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	var current := DisplayServer.window_get_mode()
	var is_full := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != fullscreen:
		DisplayServer.window_set_mode(wanted)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save() -> bool:
	var config := ConfigFile.new()
	for key: String in DEFAULTS:
		config.set_value("settings", key, get(key))
	config.set_value("input", "bindings", TEBindings.changed_bindings())
	var error := config.save(PATH)
	apply()
	return error == OK

## Put every option and binding back to its default. Call save() to keep it.
func reset() -> void:
	for key: String in DEFAULTS:
		set(key, DEFAULTS[key])
	TEBindings.reset()
	apply()
