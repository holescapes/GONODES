class_name FileInDAT
extends GNDatBase
## Reads a file from disk into a table or text.
## Supports CSV, TSV, JSON, and plain text formats with auto-detection.


func _init() -> void:
	node_type = "file_in"
	node_description = "Read a file (CSV, TSV, JSON, or text) from disk into a table."


## Local filesystem access — not available on web (no FileAccess to arbitrary paths).
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "File contents")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("filepath", "",
		"File Path", "Path to file (res:// or user://)"))
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Auto", "CSV", "TSV", "JSON", "Text"]), 0,
		"Mode", "Parse format"))
	add_parameter(GNParameter.create_bool("has_header", true,
		"Has Header", "First row is header"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var path: String = get_param_value("filepath")
	if path.is_empty():
		return out
	if not FileAccess.file_exists(path):
		push_warning("FileInDAT: File not found: %s" % path)
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("FileInDAT: Cannot open file: %s" % path)
		return out
	var content := file.get_as_text()
	file.close()

	var mode: int = get_param_value("mode")
	# Auto-detect based on extension
	if mode == 0:
		if path.ends_with(".csv"):
			mode = 1
		elif path.ends_with(".tsv"):
			mode = 2
		elif path.ends_with(".json"):
			mode = 3
		else:
			mode = 4  # Text

	if mode == 4:
		out.is_table = false
		out.set_text(content)
		return out

	out.is_table = true
	var header_flag: bool = get_param_value("has_header")
	out.has_header = header_flag

	if mode == 3:  # JSON
		var parsed = JSON.parse_string(content)
		if parsed is Array and parsed.size() > 0:
			if parsed[0] is Dictionary:
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

	# CSV / TSV
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
