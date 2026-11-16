extends Node
## Autoload "Settings". Player options, stored in user://settings.cfg.

const PATH := "user://settings.cfg"

## Multiplies every QTE window. Above 1 gives more time.
var qte_window_scale := 1.0
## Multiplies timed-choice windows. Zero removes the timer.
var choice_time_scale := 1.0
## Multiplies how long an unvoiced line stays up.
var text_hold_scale := 1.0
var subtitle_size := 24
var master_volume := 1.0

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key: String in config.get_section_keys("settings"):
			if key in self:
				set(key, config.get_value("settings", key))
	apply()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

func save() -> void:
	var config := ConfigFile.new()
	for key: String in ["qte_window_scale", "choice_time_scale", "text_hold_scale", "subtitle_size", "master_volume"]:
		config.set_value("settings", key, get(key))
	config.save(PATH)
	apply()
