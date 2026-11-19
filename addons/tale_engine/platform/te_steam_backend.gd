class_name TESteamBackend
extends TEPlatformBackend
## Steam through the GodotSteam extension (https://godotsteam.com), which the
## game adds itself; the engine does not ship it. Calls go through `steam`, the
## "Steam" engine singleton, by name, so this script loads without it.
##
## Achievement ids are the API names set in Steamworks. Cloud saves use Steam
## Auto-Cloud: in Steamworks, add a root of "WinAppDataRoaming" (Windows) and
## "LinuxXdgDataHome" (Linux and Steam Deck) with the subdirectory printed by
## save_directory(). No code is needed for that.

## The Steam singleton, or a stand-in with the same methods for tests.
var steam: Object
## Steam app id; 0 lets steam_appid.txt or the Steam client decide.
var app_id := 0
var _running := false

static func available() -> bool:
	return Engine.has_singleton("Steam")

func _init(singleton: Object = null, new_app_id: int = 0) -> void:
	steam = singleton if singleton != null else (Engine.get_singleton("Steam") if available() else null)
	app_id = new_app_id

func id() -> StringName:
	return &"steam"

func start() -> bool:
	if steam == null:
		return false
	var result: Variant = steam.call("steamInitEx", false, app_id) if steam.has_method("steamInitEx") else steam.call("steamInit")
	# steamInitEx returns {"status": 0 on success, "verbal": ...}; steamInit returns a bool or the same dictionary.
	if result is Dictionary:
		_running = int(result.get("status", 1)) == 0
	else:
		_running = result == true
	if _running and steam.has_method("requestCurrentStats"):
		steam.call("requestCurrentStats")
	return _running

func poll() -> void:
	if _running:
		steam.call("run_callbacks")

func unlock(achievement: StringName) -> bool:
	if not _running:
		return false
	var done: Variant = steam.call("setAchievement", String(achievement))
	steam.call("storeStats")
	return done != false

func is_unlocked(achievement: StringName) -> bool:
	if not _running:
		return false
	var state: Variant = steam.call("getAchievement", String(achievement))
	return state is Dictionary and state.get("ret", false) and state.get("achieved", false)

func clear(achievement: StringName) -> bool:
	if not _running:
		return false
	steam.call("clearAchievement", String(achievement))
	steam.call("storeStats")
	return true

func player_name() -> String:
	return String(steam.call("getPersonaName")) if _running else ""

## Steam reports languages as "english", "french", ...; map the common ones.
func language() -> String:
	if not _running or not steam.has_method("getCurrentGameLanguage"):
		return ""
	const CODES := {"english": "en", "french": "fr", "german": "de", "spanish": "es", "latam": "es_419",
		"italian": "it", "japanese": "ja", "koreana": "ko", "polish": "pl", "brazilian": "pt_BR",
		"portuguese": "pt", "russian": "ru", "schinese": "zh_CN", "tchinese": "zh_TW", "turkish": "tr"}
	return CODES.get(String(steam.call("getCurrentGameLanguage")), "")

func shutdown() -> void:
	if _running and steam.has_method("steamShutdown"):
		steam.call("steamShutdown")
	_running = false
