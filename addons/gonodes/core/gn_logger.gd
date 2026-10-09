class_name GNLogger
extends RefCounted
## Centralized logging for GONODES with level filtering and toggle control.
## Uses Godot's print() / push_warning() / push_error() under the hood so all
## output appears in the Output panel.
##
## Usage:
##   GNLogger.info("CookEngine", "Frame %d cooked in %.2fms" % [f, t])
##   GNLogger.debug("NoiseTOP", "Viewport created: %s" % vp_name)
##   GNLogger.warn("Network", "Cycle detected")
##   GNLogger.error("Parameter", "Expression compile failed: %s" % err)
##
## Toggle at runtime:
##   GNLogger.enabled = true / false
##   GNLogger.level = GNLogger.Level.DEBUG  (show everything)
##   GNLogger.level = GNLogger.Level.WARN   (only warnings + errors)
##
## The editor captures whenever enabled is on, including while the log panel
## is closed. The panel only draws the latest lines, and only while it is
## open. install_godot_bridge() copies Godot's own prints, warnings, and
## errors into the same buffer and file. Those copies are not printed again,
## so the bridge cannot loop.

## Log severity levels — higher value = more severe.
enum Level {
	DEBUG = 0,   ## Verbose internals: viewport creation, topo sort, param resolution
	INFO  = 1,   ## Key lifecycle events: node added, connection made, cook frame summary
	WARN  = 2,   ## Recoverable issues: missing input, fallback used
	ERROR = 3,   ## Failures: expression errors, cycle detected, null cook result
	NONE  = 4,   ## Logging fully disabled (no output regardless of enabled flag)
}

## Master switch — when false, no log output is produced at any level.
## The editor leaves this on. Closing the log panel does not clear it.
static var enabled: bool = true

## Minimum level to output. Messages below this level are silently dropped.
static var level: Level = Level.INFO

## Level from Preferences. The log panel's DBG filter can temporarily
## lower `level` to DEBUG, then restore this.
static var baseline_level: Level = Level.INFO

## When true, each log line includes the frame number from Engine.get_frames_drawn().
static var show_frame: bool = true

## When true, each log line includes a millisecond timestamp.
static var show_timestamp: bool = false

## Per-category mute list. Add category strings to suppress specific subsystems.
## Example: GNLogger.muted_categories["CookEngine"] = true
static var muted_categories: Dictionary = {}

## Optional: limit how often repeated messages print (0 = no throttle).
## Keyed by message hash, value = last frame printed.
static var _throttle_cache: Dictionary = {}
static var throttle_interval_frames: int = 0  # 0 = disabled

## External sink — when set, every accepted log message is forwarded here.
## Signature: func(level: Level, category: String, message: String) -> void
static var log_sink: Callable = Callable()

## Toast sink — when set, WARN and ERROR messages are forwarded for display
## as transient toast notifications in the editor UI.
## Signature: func(level: Level, message: String) -> void
static var toast_sink: Callable = Callable()

## File logging — when a path is set via set_log_file(), every accepted log
## message is also appended to the file.  Useful for debugging exported apps.
static var _log_file: FileAccess = null
static var _log_file_path: String = ""

## True while this logger is printing into Godot, so the bridge ignores
## the line it just emitted.
static var _emit_lock: bool = false

static var _godot_bridge: Logger = null

## Latest lines for the log panel. The file, when set, keeps the full session.
const DEFAULT_PANEL_LINES := 50
static var panel_line_limit: int = DEFAULT_PANEL_LINES
static var _recent_lines: Array[Dictionary] = []

## Lines accepted before the log file exists (no patch path yet).
const _FILE_BACKLOG_LIMIT := 4000
static var _file_backlog: PackedStringArray = PackedStringArray()
static var _file_wanted: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════════════════

## True when a message at this level and category would be printed.
## Callers that build a string every frame should check this first.
static func will_log(msg_level: Level, category: String) -> bool:
	if not enabled or msg_level < level:
		return false
	return not muted_categories.has(category)


## Logs a DEBUG-level message (verbose internals).
static func debug(category: String, message: String) -> void:
	_log(Level.DEBUG, category, message)


## Logs an INFO-level message (key events).
static func info(category: String, message: String) -> void:
	_log(Level.INFO, category, message)


## Logs a WARN-level message (also calls push_warning for Godot's error panel).
static func warn(category: String, message: String) -> void:
	_log(Level.WARN, category, message)


## Logs an ERROR-level message (also calls push_error for Godot's error panel).
static func error(category: String, message: String) -> void:
	_log(Level.ERROR, category, message)


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

static func _log(msg_level: Level, category: String, message: String, echo: bool = true) -> void:
	if not enabled:
		return
	if msg_level < level:
		return
	if muted_categories.has(category):
		return

	# Throttle check
	if throttle_interval_frames > 0:
		var key := message.hash()
		var current_frame := Engine.get_frames_drawn()
		if _throttle_cache.has(key):
			var last_frame: int = _throttle_cache[key]
			if current_frame - last_frame < throttle_interval_frames:
				return
		_throttle_cache[key] = current_frame

	var prefix := _build_prefix(msg_level, category)
	var full_msg := "%s %s" % [prefix, message]

	# Route to appropriate Godot output. The lock keeps the bridge from
	# recording this line a second time. echo is false for lines that
	# Godot already printed.
	if echo:
		_emit_lock = true
		match msg_level:
			Level.ERROR:
				push_error(full_msg)
			Level.WARN:
				push_warning(full_msg)
			_:
				print(full_msg)
		_emit_lock = false

	_recent_lines.append({
		"level": msg_level,
		"category": category,
		"message": message,
	})
	while _recent_lines.size() > panel_line_limit:
		_recent_lines.pop_front()

	# Forward to external sink (e.g. editor log panel, ErrorDAT)
	if log_sink.is_valid():
		log_sink.call(msg_level, category, message)

	# Forward WARN/ERROR to toast sink (editor overlay notifications)
	if toast_sink.is_valid() and msg_level >= Level.WARN:
		toast_sink.call(msg_level, message)

	# Append to log file, or hold the line until the patch path is known.
	if _log_file != null:
		_log_file.store_line(full_msg)
		_log_file.flush()
	elif _file_wanted:
		_file_backlog.append(full_msg)
		while _file_backlog.size() > _FILE_BACKLOG_LIMIT:
			_file_backlog.remove_at(0)


static func _build_prefix(msg_level: Level, category: String) -> String:
	var parts := PackedStringArray()

	# Level tag
	match msg_level:
		Level.DEBUG:
			parts.append("[DEBUG]")
		Level.INFO:
			parts.append("[INFO] ")
		Level.WARN:
			parts.append("[WARN] ")
		Level.ERROR:
			parts.append("[ERROR]")

	# Optional frame number
	if show_frame:
		parts.append("[F%d]" % Engine.get_frames_drawn())

	# Optional timestamp
	if show_timestamp:
		parts.append("[%.1fms]" % (Time.get_ticks_msec()))

	# Category
	parts.append("[%s]" % category)

	return " ".join(parts)


## Convenience: returns a one-line status summary for debugging.
static func get_status() -> String:
	var level_names := ["DEBUG", "INFO", "WARN", "ERROR", "NONE"]
	return "GNLogger: enabled=%s level=%s frame=%s" % [
		str(enabled), level_names[level], str(show_frame)]


## Copies Godot prints, warnings, and errors into this logger.
## Safe to call more than once. Capture does not depend on the log panel.
static func install_godot_bridge() -> void:
	if _godot_bridge != null:
		return
	_capture_engine_banner()
	_godot_bridge = _GodotLogBridge.new()
	OS.add_logger(_godot_bridge)


## Preferences level. The log panel re-applies its DBG override after this.
static func set_baseline_level(lvl: Level) -> void:
	baseline_level = lvl
	level = lvl


## How many lines the log panel can show. Older lines stay in the log file.
static func set_panel_line_limit(count: int) -> void:
	panel_line_limit = clampi(count, 1, 5000)
	while _recent_lines.size() > panel_line_limit:
		_recent_lines.pop_front()


## Copy of the lines the panel is allowed to draw.
static func get_recent_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	lines.assign(_recent_lines)
	return lines


static func clear_recent_lines() -> void:
	_recent_lines.clear()


## A file name only. Empty, or a path, is rejected.
static func sanitize_log_file_name(raw: String) -> String:
	var name := raw.strip_edges()
	if name.is_empty() or name == "." or name == "..":
		return ""
	if name.contains("/") or name.contains("\\") or name.contains(":"):
		return ""
	for ch in ["<", ">", "\"", "|", "?", "*"]:
		if name.contains(ch):
			return ""
	return name


## `patch_dir/file_name` when both parts are usable.
static func log_path_beside_patch(patch_path: String, file_name: String) -> String:
	var name := sanitize_log_file_name(file_name)
	if name.is_empty() or patch_path.strip_edges().is_empty():
		return ""
	return patch_path.get_base_dir().path_join(name)


## Remember lines until set_log_file() has a path. Used before the patch is saved.
static func arm_log_file() -> void:
	_close_log_handle()
	_file_wanted = true


## Godot prints its version, device, and codec list before any script runs.
## The version and device can be rebuilt. The codec list cannot.
static func _capture_engine_banner() -> void:
	var info := Engine.get_version_info()
	var hash := str(info.get("hash", ""))
	if hash.length() > 9:
		hash = hash.substr(0, 9)
	_log(Level.INFO, "Godot",
		"Godot Engine v%s.%s.%s.%s.%s.%s - https://godotengine.org" % [
			info.get("major", 0), info.get("minor", 0), info.get("patch", 0),
			info.get("status", ""), info.get("build", ""), hash], false)
	var driver := str(RenderingServer.get_current_rendering_driver_name())
	var pretty: String = {
		"d3d12": "D3D12",
		"vulkan": "Vulkan",
		"opengl3": "OpenGL",
		"metal": "Metal",
	}.get(driver, driver)
	var api := str(RenderingServer.get_video_adapter_api_version())
	var head := pretty
	if not api.is_empty():
		head = "%s %s" % [pretty, api]
	var method := str(RenderingServer.get_current_rendering_method())
	var method_label: String = {
		"forward_plus": "Forward+",
		"mobile": "Mobile",
		"gl_compatibility": "Compatibility",
	}.get(method, method)
	var line := "%s - %s" % [head, method_label]
	var vendor := str(RenderingServer.get_video_adapter_vendor())
	var adapter := str(RenderingServer.get_video_adapter_name())
	if not vendor.is_empty() or not adapter.is_empty():
		line = "%s - Using Device #0: %s - %s" % [line, vendor, adapter]
	_log(Level.INFO, "Godot", line, false)


## Opens a log file at the given path and appends. An empty path disables it.
## The same open path is left alone so a later save does not wipe the file.
static func set_log_file(path: String) -> void:
	if path.is_empty():
		close_log_file()
		return
	if path == _log_file_path and _log_file != null:
		return
	_close_log_handle()
	_file_wanted = true
	if FileAccess.file_exists(path):
		_log_file = FileAccess.open(path, FileAccess.READ_WRITE)
		if _log_file != null:
			_log_file.seek_end()
	else:
		_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file == null:
		push_warning("GNLogger: could not open log file '%s' — error %d" % [
			path, FileAccess.get_open_error()])
		return
	_log_file_path = path
	_log_file.store_line("# GONODES log — %s" % Time.get_datetime_string_from_system())
	for pending in _file_backlog:
		_log_file.store_line(pending)
	_file_backlog = PackedStringArray()
	_log_file.flush()


## Closes the current log file and drops any lines waiting for a path.
static func close_log_file() -> void:
	_close_log_handle()
	_file_wanted = false
	_file_backlog = PackedStringArray()


static func _close_log_handle() -> void:
	if _log_file != null:
		_log_file.flush()
		_log_file.close()
		_log_file = null
		_log_file_path = ""


## Forwards Godot's logger into GNLogger without printing again.
class _GodotLogBridge extends Logger:
	var _recent: PackedStringArray = PackedStringArray()

	func _log_message(message: String, error: bool) -> void:
		var lvl := GNLogger.Level.ERROR if error else GNLogger.Level.INFO
		_ingest(message, lvl)

	func _log_error(_function: String, file: String, line: int, code: String,
			rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		var lvl := GNLogger.Level.ERROR
		# Logger.ErrorType.WARNING is 1. The enum member name is not stable
		# across Godot 4.7 script bindings, so compare the value.
		if error_type == 1:
			lvl = GNLogger.Level.WARN
		var text := rationale if not rationale.is_empty() else code
		if text.is_empty():
			text = _function
		var where := file.get_file()
		if line > 0:
			where = "%s:%d" % [where, line]
		_ingest("%s — %s" % [where, text], lvl)

	func _ingest(message: String, lvl: GNLogger.Level) -> void:
		if GNLogger._emit_lock:
			return
		var cleaned := message.strip_edges()
		if cleaned.is_empty() or _is_own_line(cleaned) or _is_duplicate(cleaned):
			return
		_remember(cleaned)
		var split := _split_print(cleaned)
		GNLogger._log(lvl, split[0], split[1], false)

	func _split_print(message: String) -> PackedStringArray:
		if message.begins_with("["):
			var end := message.find("]")
			if end > 1 and end < 48:
				var rest := message.substr(end + 1).strip_edges()
				if not rest.is_empty():
					return PackedStringArray([message.substr(1, end - 1), rest])
		return PackedStringArray(["Godot", message])

	func _is_own_line(message: String) -> bool:
		return message.begins_with("[DEBUG]") \
			or message.begins_with("[INFO]") \
			or message.begins_with("[WARN]") \
			or message.begins_with("[ERROR]")

	func _is_duplicate(message: String) -> bool:
		for prev in _recent:
			if prev == message:
				return true
			if prev.length() >= 24 and message.length() >= 24:
				if prev.contains(message) or message.contains(prev):
					return true
		return false

	func _remember(message: String) -> void:
		_recent.append(message)
		while _recent.size() > 8:
			_recent.remove_at(0)
