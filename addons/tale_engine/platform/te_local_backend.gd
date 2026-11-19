class_name TELocalBackend
extends TEPlatformBackend
## No store: achievements are kept in user://achievements.cfg so they still
## work, and can be checked, in development and DRM-free builds.

var path := "user://achievements.cfg"
var _unlocked: Dictionary = {}

func id() -> StringName:
	return &"local"

func start() -> bool:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for key in config.get_section_keys("unlocked") if config.has_section("unlocked") else PackedStringArray():
			if config.get_value("unlocked", key, false) == true:
				_unlocked[StringName(key)] = true
	return true

func unlock(achievement: StringName) -> bool:
	if _unlocked.has(achievement):
		return true
	_unlocked[achievement] = true
	return _save()

func is_unlocked(achievement: StringName) -> bool:
	return _unlocked.has(achievement)

func clear(achievement: StringName) -> bool:
	_unlocked.erase(achievement)
	return _save()

func _save() -> bool:
	var config := ConfigFile.new()
	for key: StringName in _unlocked:
		config.set_value("unlocked", String(key), true)
	return config.save(path) == OK
