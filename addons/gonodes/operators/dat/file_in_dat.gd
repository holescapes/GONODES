class_name FileInDAT
extends GNDatBase
## Reads a file from disk into a table or text.
## Supports CSV, TSV, JSON, and plain text formats with auto-detection.
##
## With **async_load** ON, file bytes are read on a worker thread; parsing
## runs on the cook thread once the read completes. Previous table/text is
## held until the new path is ready.


var _loaded_path: String = ""
var _cached_content: String = ""
var _async_path: String = ""
var _async_pending: bool = false
var _async_result: String = ""
var _async_mutex: Mutex = Mutex.new()
var _async_thread: Thread = null


func _init() -> void:
	node_type = "file_in"
	thread_safe = false


## Local filesystem access — not available on web (no FileAccess to arbitrary paths).
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "File contents")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_file("filepath", "Path to the filepath",
		PackedStringArray(["*.csv", "*.tsv", "*.json", "*.txt", "*.md", "*.cfg", "*.ini"]),
		"File Path", "Path to file (res:// or user://)"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Auto", "CSV", "TSV", "JSON", "Text"]), 0,
		"Mode", "Parse format"))
	add_parameter(GNParameter.create_bool("has_header", true,
		"Has Header", "First row is header"))
	add_parameter(GNParameter.create_bool("async_load", false,
		"Async Load", "Read file on a background thread; hold last data until ready."))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var path: String = get_param_value("filepath")
	if path.is_empty():
		return out

	var resolved := GNResourceLoader.resolve(path, project_dir)
	if resolved.is_empty() or not FileAccess.file_exists(resolved):
		GNLogger.warn("FileInDAT", "File not found: %s" % path)
		return out

	var async_load: bool = get_param_value("async_load")
	_poll_async()

	if async_load:
		if resolved != _loaded_path and not _async_pending:
			_start_async_read(resolved)
		if _is_async_pending():
			request_keep_dirty()
			node_warning = "Loading…"
			if not _cached_content.is_empty():
				return _parse_content(_cached_content, resolved, out)
			out.is_table = false
			out.set_text("(loading…)")
			return out
	else:
		_cancel_async()

	var content := _cached_content
	if resolved != _loaded_path or content.is_empty():
		var file := FileAccess.open(resolved, FileAccess.READ)
		if file == null:
			GNLogger.warn("FileInDAT", "Cannot open file: %s" % path)
			return out
		content = file.get_as_text()
		file.close()
		_cached_content = content
		_loaded_path = resolved

	node_warning = ""
	return _parse_content(content, resolved, out)


func _parse_content(content: String, resolved: String, out: GNTableData) -> GNTableData:
	var mode: int = get_param_value("mode")
	if mode == 0:
		if resolved.ends_with(".csv"):
			mode = 1
		elif resolved.ends_with(".tsv"):
			mode = 2
		elif resolved.ends_with(".json"):
			mode = 3
		else:
			mode = 4

	if mode == 4:
		out.is_table = false
		out.set_text(content)
		return out

	out.is_table = true
	var header_flag: bool = get_param_value("has_header")
	out.has_header = header_flag

	if mode == 3:
		var parsed = JSON.parse_string(content)
		if parsed is Array and parsed.size() > 0 and parsed[0] is Dictionary:
			var keys: Array = parsed[0].keys()
			var hdr := PackedStringArray()
			for k in keys:
				hdr.append(str(k))
			out.set_headers(hdr)
			for item in parsed:
				var row := PackedStringArray()
				for k in keys:
					row.append(str(item.get(k, "")))
				out.append_row(row)
		return out

	var delim := "," if mode == 1 else "\t"
	var lines := content.split("\n", false)
	for i in range(lines.size()):
		var cells := PackedStringArray()
		for cell_val in lines[i].split(delim):
			cells.append(cell_val.strip_edges())
		if i == 0 and header_flag:
			out.set_headers(cells)
		else:
			out.append_row(cells)
	return out


func _is_async_pending() -> bool:
	_async_mutex.lock()
	var pending: bool = _async_pending
	_async_mutex.unlock()
	return pending


func _start_async_read(resolved: String) -> void:
	_cancel_async()
	_async_mutex.lock()
	_async_path = resolved
	_async_pending = true
	_async_result = ""
	_async_mutex.unlock()
	_async_thread = Thread.new()
	_async_thread.start(func():
		var text := ""
		if FileAccess.file_exists(resolved):
			var f := FileAccess.open(resolved, FileAccess.READ)
			if f != null:
				text = f.get_as_text()
				f.close()
		_async_mutex.lock()
		_async_result = text
		_async_pending = false
		_async_mutex.unlock()
	)


func _poll_async() -> void:
	_async_mutex.lock()
	var pending: bool = _async_pending
	var result: String = _async_result
	var path: String = _async_path
	_async_mutex.unlock()
	if pending:
		return
	if _async_thread != null and not _async_thread.is_alive():
		_async_thread.wait_to_finish()
		_async_thread = null
	if path.is_empty():
		return
	if path == _async_path and not result.is_empty():
		_cached_content = result
		_loaded_path = path
		_async_mutex.lock()
		_async_path = ""
		_async_result = ""
		_async_mutex.unlock()


func _cancel_async() -> void:
	if _async_thread != null:
		if _async_thread.is_alive():
			_async_thread.wait_to_finish()
		_async_thread = null
	_async_mutex.lock()
	_async_pending = false
	_async_result = ""
	_async_path = ""
	_async_mutex.unlock()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_async()
