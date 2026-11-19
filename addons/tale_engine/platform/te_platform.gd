extends Node
## Autoload "Platform". Achievements, the save directory and crash reports,
## behind one interface whatever store the game ships on.
##
##   do Platform.unlock("paid_the_tab")       from dialogue or code
##   Platform.backend.id()                    &"steam" or &"local"
##
## Backend: Steam when the GodotSteam singleton is present and starts, else
## local. Set the project setting tale_engine/platform/steam_app_id for
## development without steam_appid.txt.
##
## Crash capture: a lock file marks a running session. If it is still there at
## the next start, the last run did not exit cleanly; its log and recent
## errors are copied to user://crash_reports/ and last_crash_report names the
## file. Faults reported through TEFault are written there too.

signal unlocked(achievement: StringName)

const LOCK := "user://session.lock"
const REPORTS := "user://crash_reports"
const KEEP_REPORTS := 10
const APP_ID_SETTING := "tale_engine/platform/steam_app_id"

var backend: TEPlatformBackend
var errors := TEErrorLog.new()
## Path of the report written at start-up for an unclean exit, or "".
var last_crash_report := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(errors)
	last_crash_report = _check_last_session()
	_write_lock()
	use_backend(_pick_backend())
	TEFault.listeners.append(_on_fault)
	if "--te-smoke" in OS.get_cmdline_user_args():
		add_child.call_deferred(TESmoke.new())

func _pick_backend() -> TEPlatformBackend:
	if TESteamBackend.available():
		var steam := TESteamBackend.new(null, int(ProjectSettings.get_setting(APP_ID_SETTING, 0)))
		if steam.start():
			return steam
		push_warning("Platform: Steam is present but did not start; using local achievements.")
	return TELocalBackend.new()

## Swap backends, starting the new one if needed. Tests use this.
func use_backend(new_backend: TEPlatformBackend, started := false) -> void:
	if backend != null and backend != new_backend:
		backend.shutdown()
	backend = new_backend
	if not started and backend is TELocalBackend:
		backend.start()

func _process(_delta: float) -> void:
	if backend != null:
		backend.poll()

func unlock(achievement: StringName) -> bool:
	if backend == null or achievement == &"":
		return false
	var already := backend.is_unlocked(achievement)
	var done := backend.unlock(achievement)
	if done and not already:
		unlocked.emit(achievement)
	return done

func is_unlocked(achievement: StringName) -> bool:
	return backend != null and backend.is_unlocked(achievement)

func save_directory() -> String:
	return backend.save_directory() if backend != null else OS.get_user_data_dir()

# --- Crash and log capture ----------------------------------------------------

## Write a report now: recent errors plus the reason. Returns its path.
func write_report(reason: String, log_text := "") -> String:
	DirAccess.make_dir_recursive_absolute(REPORTS)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/report_%s_%d.txt" % [REPORTS, stamp, Time.get_ticks_usec() % 1000000]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_line("Reason: " + reason)
	file.store_line("Game: %s %s" % [ProjectSettings.get_setting("application/config/name", ""), ProjectSettings.get_setting("application/config/version", "")])
	file.store_line("Engine: %s on %s, %s" % [Engine.get_version_info().string, OS.get_name(), RenderingServer.get_video_adapter_name()])
	file.store_line("Backend: %s" % (backend.id() if backend != null else &"none"))
	file.store_line("\nRecent errors:")
	for line in errors.lines():
		file.store_line(line)
	if log_text != "":
		file.store_line("\nLog of that session:")
		file.store_string(log_text)
	file.close()
	_prune()
	return path

## Reports on disk, newest first.
func reports() -> PackedStringArray:
	var found := PackedStringArray()
	for name in DirAccess.get_files_at(REPORTS) if DirAccess.dir_exists_absolute(REPORTS) else PackedStringArray():
		found.append("%s/%s" % [REPORTS, name])
	found.sort()
	found.reverse()
	return found

func _prune() -> void:
	var all := reports()
	for i in range(KEEP_REPORTS, all.size()):
		DirAccess.remove_absolute(all[i])

func _check_last_session() -> String:
	if not FileAccess.file_exists(LOCK):
		return ""
	var started := FileAccess.get_file_as_string(LOCK).strip_edges()
	return write_report("The previous session (started %s) did not exit cleanly." % started, _previous_log())

## Godot moves the last session's log aside when a new one starts; read the
## newest rotated log.
func _previous_log() -> String:
	var directory := "user://logs"
	if not DirAccess.dir_exists_absolute(directory):
		return ""
	var logs := Array(DirAccess.get_files_at(directory)).filter(func(name: String) -> bool:
		return name.ends_with(".log") and name != "godot.log")
	if logs.is_empty():
		return ""
	logs.sort()
	return FileAccess.get_file_as_string("%s/%s" % [directory, logs.back()])

func _write_lock() -> void:
	var file := FileAccess.open(LOCK, FileAccess.WRITE)
	if file != null:
		file.store_line(Time.get_datetime_string_from_system())

## Mark the session as having ended cleanly.
func end_session() -> void:
	if FileAccess.file_exists(LOCK):
		DirAccess.remove_absolute(LOCK)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		end_session()

func _exit_tree() -> void:
	end_session()
	# The project theme outlives the scene tree; drop its system-font fallbacks
	# now so their cached font files are released before shutdown.
	var theme := ThemeDB.get_project_theme()
	if theme != null and theme.default_font != null:
		theme.default_font.fallbacks = []
	if backend != null:
		backend.shutdown()
	OS.remove_logger(errors)
	TEFault.listeners.erase(_on_fault)

func _on_fault(message: String) -> void:
	write_report("Fault: " + message)
