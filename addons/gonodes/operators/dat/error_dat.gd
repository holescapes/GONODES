class_name ErrorDAT
extends GNDatBase
## Captures logged warnings and errors from GNLogger into a table.
## Hooks into GNLogger.log_sink so every GNLogger.warn / GNLogger.error
## call is recorded automatically. The table columns are:
##   level | category | message | timestamp

var _rows: Array[PackedStringArray] = []


func _init() -> void:
	node_type = "error"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Error / warning log table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("level_filter",
		PackedStringArray(["Errors Only", "Warnings & Errors", "All"]),
		1, "Level Filter", "Minimum severity to capture"))
	add_parameter(GNParameter.create_int("max_rows", 200, 1, 5000,
		"Max Rows", "Maximum log entries to keep"))
	add_parameter(GNParameter.create_bool("clear", false, "Clear",
		"Pulse to clear the log"))
	# After parameters exist. A bare constructor (deprecation probe, port
	# cache) must not take the log: it has no level_filter yet, and the
	# next log line would warn about that missing parameter.
	GNLogger.log_sink = _on_log


func _cook(_inputs: Array[GNData]) -> GNData:
	if get_param_value("clear"):
		_rows.clear()

	# Trim oldest
	var max_rows: int = get_param_value("max_rows")
	while _rows.size() > max_rows:
		_rows.pop_front()

	var tbl: GNTableData = _prepare_table(true)
	tbl.set_headers(PackedStringArray(["level", "category", "message", "timestamp"]))
	for row in _rows:
		tbl.append_row(row)
	return tbl


# ─── Logger sink ─────────────────────────────────────────────────────────────

func _on_log(level: GNLogger.Level, category: String, message: String) -> void:
	if get_parameter("level_filter") == null:
		return
	var filter_idx: int = get_param_value("level_filter")
	# 0 = Errors Only (ERROR=3), 1 = Warnings & Errors (WARN=2), 2 = All
	var min_level: int = [GNLogger.Level.ERROR, GNLogger.Level.WARN, GNLogger.Level.DEBUG][filter_idx]
	if level < min_level:
		return

	var level_name: String = ["DEBUG", "INFO", "WARN", "ERROR"][mini(level, 3)]
	var ts: String = Time.get_time_string_from_system()
	var max_rows: int = get_param_value("max_rows")

	_rows.append(PackedStringArray([level_name, category, message, ts]))
	while _rows.size() > max_rows:
		_rows.pop_front()
	mark_dirty()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Unhook sink if it is still ours
		if GNLogger.log_sink == _on_log:
			GNLogger.log_sink = Callable()
