extends TestSuite
## Phase 9: platform backends, achievements, crash and log capture.

## Stands in for the GodotSteam singleton: same method names, no Steam.
class FakeSteam:
	extends RefCounted
	var achieved: Dictionary = {}
	var stored := 0
	var callbacks := 0
	var init_status := 0
	func steamInitEx(_retrieve: bool, _app_id: int) -> Dictionary:
		return {"status": init_status, "verbal": "fake"}
	func run_callbacks() -> void:
		callbacks += 1
	func setAchievement(name: String) -> bool:
		achieved[name] = true
		return true
	func getAchievement(name: String) -> Dictionary:
		return {"ret": true, "achieved": achieved.get(name, false)}
	func clearAchievement(name: String) -> bool:
		achieved.erase(name)
		return true
	func storeStats() -> bool:
		stored += 1
		return true
	func getPersonaName() -> String:
		return "Tester"
	func getCurrentGameLanguage() -> String:
		return "schinese"

func run() -> void:
	local_backend()
	steam_backend()
	crash_capture()

func local_backend() -> void:
	var path := "user://test_achievements.cfg"
	DirAccess.remove_absolute(path)
	var local := TELocalBackend.new()
	local.path = path
	local.start()
	var previous := Platform.backend
	Platform.use_backend(local, true)
	var heard: Array = []
	var on_unlock := func(id: StringName) -> void: heard.append(id)
	Platform.unlocked.connect(on_unlock)
	expect(Platform.unlock(&"paid_the_tab") and Platform.is_unlocked(&"paid_the_tab"), "an achievement unlocks")
	Platform.unlock(&"paid_the_tab")
	expect(heard == [&"paid_the_tab"], "the unlocked signal fires once per achievement")
	var reloaded := TELocalBackend.new()
	reloaded.path = path
	reloaded.start()
	expect(reloaded.is_unlocked(&"paid_the_tab"), "local achievements survive a restart")
	expect(reloaded.clear(&"paid_the_tab") and not reloaded.is_unlocked(&"paid_the_tab"), "and can be cleared for testing")
	Platform.unlocked.disconnect(on_unlock)
	Platform.use_backend(previous, true)
	DirAccess.remove_absolute(path)
	expect(Platform.backend is TELocalBackend, "without GodotSteam the local backend is used")
	expect(Platform.save_directory() == OS.get_user_data_dir(), "saves live in the user data folder")

func steam_backend() -> void:
	var fake := FakeSteam.new()
	var steam := TESteamBackend.new(fake, 480)
	expect(steam.start(), "Steam starts when steamInitEx reports success")
	steam.poll()
	expect(fake.callbacks == 1, "callbacks are pumped every frame")
	expect(steam.unlock(&"ACH_WIN") and fake.achieved.has("ACH_WIN") and fake.stored == 1, "unlocking sets and stores the achievement")
	expect(steam.is_unlocked(&"ACH_WIN"), "unlocked state is read back from Steam")
	expect(steam.player_name() == "Tester" and steam.language() == "zh_CN", "persona name and Steam language map across")
	steam.shutdown()
	expect(not steam.unlock(&"ACH_OTHER"), "nothing reaches Steam after shutdown")
	var failing := FakeSteam.new()
	failing.init_status = 2
	expect(not TESteamBackend.new(failing).start(), "a failed init leaves Steam off")
	expect(not TESteamBackend.new(null).start() or TESteamBackend.available(), "no singleton, no Steam")

func crash_capture() -> void:
	expect(FileAccess.file_exists(Platform.LOCK), "a running session holds the lock file")
	Platform.errors.clear()
	Platform.errors._log_error("probe", "res://x.gd", 7, "", "a recorded error", false, 0, [])
	Platform.errors._log_message("plain output", false)
	expect(Platform.errors.lines().size() == 1 and Platform.errors.lines()[0].contains("a recorded error (res://x.gd:7"),
		"engine errors are kept for reports; ordinary output is not")
	for report in Platform.reports():
		DirAccess.remove_absolute(report)
	var path := Platform._check_last_session()
	expect(path != "" and FileAccess.get_file_as_string(path).contains("did not exit cleanly"),
		"a lock left by the last run produces a crash report")
	expect(FileAccess.get_file_as_string(path).contains("a recorded error"), "the report carries recent errors")
	var faults := capture_faults()
	TEFault.report("Flow: probe fault")
	release_faults()
	var newest := Platform.reports()[0]
	expect(faults.size() == 1 and FileAccess.get_file_as_string(newest).contains("Fault: Flow: probe fault"),
		"faults are written to a report even when a handler takes them")
	for i in Platform.KEEP_REPORTS + 3:
		Platform.write_report("probe %d" % i)
	expect(Platform.reports().size() == Platform.KEEP_REPORTS, "old reports are pruned")
	for report in Platform.reports():
		DirAccess.remove_absolute(report)
	Platform.errors.clear()
