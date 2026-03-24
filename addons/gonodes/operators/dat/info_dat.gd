class_name InfoDAT
extends GNDatBase
## Outputs system information as a DAT table.
## Columns: "property", "value".
## Includes FPS, frame number, elapsed time, renderer info, etc.


func _init() -> void:
	node_type = "info"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "System info table")


func _init_parameters() -> void:
	pass


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()
	_cached_table.is_table = true
	_cached_table.has_header = true
	_cached_table.set_headers(PackedStringArray(["property", "value"]))

	# Engine info
	_cached_table.append_row(PackedStringArray(["fps", "%.1f" % Engine.get_frames_per_second()]))
	_cached_table.append_row(PackedStringArray(["frame", str(current_frame)]))
	_cached_table.append_row(PackedStringArray(["elapsed_time", "%.3f" % elapsed_time]))
	_cached_table.append_row(PackedStringArray(["delta", "%.6f" % current_delta]))
	_cached_table.append_row(PackedStringArray(["engine_version", Engine.get_version_info().get("string", "unknown")]))

	# OS info
	_cached_table.append_row(PackedStringArray(["os", OS.get_name()]))
	_cached_table.append_row(PackedStringArray(["processor_name", OS.get_processor_name()]))
	_cached_table.append_row(PackedStringArray(["processor_count", str(OS.get_processor_count())]))

	# Display info
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	_cached_table.append_row(PackedStringArray(["screen_size", "%d×%d" % [screen_size.x, screen_size.y]]))

	# Memory
	_cached_table.append_row(PackedStringArray(["static_memory", _format_bytes(OS.get_static_memory_usage())]))

	return _cached_table


## Formats bytes into a human-readable string.
func _format_bytes(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1048576:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1073741824:
		return "%.1f MB" % (bytes / 1048576.0)
	else:
		return "%.2f GB" % (bytes / 1073741824.0)
