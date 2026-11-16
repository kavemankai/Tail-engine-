extends Node
## Autoload "Settings". Player options, stored in user://settings.cfg.

const PATH := "user://settings.cfg"
const LIMITS := {
	"qte_window_scale": Vector2(1.0, 3.0),
	"choice_time_scale": Vector2(0.0, 3.0),
	"text_hold_scale": Vector2(0.75, 2.0),
	"subtitle_size": Vector2(20, 36),
	"master_volume": Vector2(0, 1),
}

## Multiplies every QTE window. Above 1 gives more time.
var qte_window_scale := 1.0
## Multiplies timed-choice windows. Zero removes the timer.
var choice_time_scale := 1.0
## Multiplies how long an unvoiced line stays up.
var text_hold_scale := 1.0
var subtitle_size := 24
var master_volume := 1.0

func _ready() -> void:
	reload()

func reload() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in LIMITS:
			var value: Variant = config.get_value("settings", key, get(key))
			if (value is int or value is float) and is_finite(float(value)):
				set(key, int(clampf(value, 20, 36)) if key == "subtitle_size" else clampf(value, LIMITS[key].x, LIMITS[key].y))
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

func save() -> bool:
	var config := ConfigFile.new()
	for key: String in ["qte_window_scale", "choice_time_scale", "text_hold_scale", "subtitle_size", "master_volume"]:
		config.set_value("settings", key, get(key))
	var error := config.save(PATH)
	apply()
	return error == OK
