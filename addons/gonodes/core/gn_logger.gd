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

## Log severity levels — higher value = more severe.
enum Level {
	DEBUG = 0,   ## Verbose internals: viewport creation, topo sort, param resolution
	INFO  = 1,   ## Key lifecycle events: node added, connection made, cook frame summary
	WARN  = 2,   ## Recoverable issues: missing input, fallback used
	ERROR = 3,   ## Failures: expression errors, cycle detected, null cook result
	NONE  = 4,   ## Logging fully disabled (no output regardless of enabled flag)
}

## Master switch — when false, no log output is produced at any level.
static var enabled: bool = false

## Minimum level to output. Messages below this level are silently dropped.
static var level: Level = Level.INFO

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

static func _log(msg_level: Level, category: String, message: String) -> void:
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

	# Route to appropriate Godot output
	match msg_level:
		Level.ERROR:
			push_error(full_msg)
		Level.WARN:
			push_warning(full_msg)
		_:
			print(full_msg)

	# Forward to external sink (e.g. editor log panel)
	if log_sink.is_valid():
		log_sink.call(msg_level, category, message)

	# Forward WARN/ERROR to toast sink (editor overlay notifications)
	if toast_sink.is_valid() and msg_level >= Level.WARN:
		toast_sink.call(msg_level, message)

	# Append to log file (if open)
	if _log_file != null:
		_log_file.store_line(full_msg)
		_log_file.flush()


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


## Opens a log file at the given path.  All subsequent accepted messages
## will be appended to it.  If a file is already open, it is closed first.
## Pass an empty string to disable file logging without calling close.
static func set_log_file(path: String) -> void:
	close_log_file()
	if path.is_empty():
		return
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file != null:
		_log_file_path = path
		_log_file.store_line("# GONODES log — %s" % Time.get_datetime_string_from_system())
		_log_file.flush()
	else:
		push_warning("GNLogger: could not open log file '%s' — error %d" % [
			path, FileAccess.get_open_error()])


## Closes the current log file (if any).
static func close_log_file() -> void:
	if _log_file != null:
		_log_file.flush()
		_log_file.close()
		_log_file = null
		_log_file_path = ""
