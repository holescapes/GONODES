class_name TableSaveOUT
extends GNOutBase
## Exports a DAT table or text to disk as CSV, TSV, JSON, or plain text.
##
## Activate the "active" toggle to start writing.

enum Format { CSV, TSV, JSON, TEXT }


func _init() -> void:
	node_type = "table_save"


## Disk write — not available on web.
func supported_platforms() -> PackedStringArray:
	return PackedStringArray(["windows", "macos", "linux", "android", "ios"])


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Table or text to save")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("active", false,
		"Active", "When enabled, saves the table/text to disk every cook"))
	add_parameter(GNParameter.create_string("file_path", "user://output/data",
		"File Path", "Output file path (without extension). Directory is created automatically."))
	add_parameter(GNParameter.create_enum("format",
		PackedStringArray(["CSV", "TSV", "JSON", "Text"]), 0,
		"Format", "Output file format"))
	add_parameter(GNParameter.create_bool("include_header", true,
		"Include Header", "Include column header row in CSV/TSV output"))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat_in: GNTableData = _get_input_dat(inputs, 0)
	if dat_in == null:
		return null

	var active: bool = get_param_value("active")
	if not active:
		return null

	var base_path: String = get_param_value("file_path")
	var fmt: int = get_param_value("format")
	var include_header: bool = get_param_value("include_header")

	# Build content string
	var content: String = ""
	var extension: String = ""

	match fmt:
		Format.CSV:
			extension = ".csv"
			content = _table_to_delimited(dat_in, ",", include_header)
		Format.TSV:
			extension = ".tsv"
			content = _table_to_delimited(dat_in, "\t", include_header)
		Format.JSON:
			extension = ".json"
			content = _table_to_json(dat_in)
		Format.TEXT:
			extension = ".txt"
			content = dat_in.text if not dat_in.is_table else dat_in.to_tsv()

	var full_path: String = base_path + extension

	# Ensure directory exists
	var dir_path: String = full_path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Write file
	var file := FileAccess.open(full_path, FileAccess.WRITE)
	if file == null:
		GNLogger.warn("TableSaveOUT",
			"'%s': Cannot open '%s' for writing (error %d)" % [id, full_path, FileAccess.get_open_error()])
		return null

	file.store_string(content)
	file.close()
	GNLogger.debug("TableSaveOUT", "'%s': Saved '%s'" % [id, full_path])

	return null


# ─── Format Helpers ────────────────────────────────────────────────────────────

## Converts a GNTableData to a delimited string (CSV or TSV).
func _table_to_delimited(table: GNTableData, delimiter: String,
		include_header: bool) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var start_row: int = 0

	if table.has_header and include_header:
		lines.append(delimiter.join(_escape_cells(table.get_headers(), delimiter)))
		start_row = 1
	elif table.has_header:
		start_row = 1  # skip header row

	for r in range(start_row, table.num_rows()):
		var row: PackedStringArray = table.get_row(r)
		lines.append(delimiter.join(_escape_cells(row, delimiter)))

	return "\n".join(lines) + "\n"


## Escapes cells that contain the delimiter, quotes, or newlines.
func _escape_cells(cells: PackedStringArray, delimiter: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cell in cells:
		if cell.contains(delimiter) or cell.contains("\"") or cell.contains("\n"):
			out.append("\"%s\"" % cell.replace("\"", "\"\""))
		else:
			out.append(cell)
	return out


## Converts a GNTableData to a JSON string.
func _table_to_json(table: GNTableData) -> String:
	if not table.is_table:
		# Text mode — wrap as simple JSON object
		return JSON.stringify({"text": table.text}, "\t")

	var rows_array: Array = []
	var headers: PackedStringArray = table.get_headers() if table.has_header else PackedStringArray()

	var start_row: int = 1 if table.has_header else 0
	for r in range(start_row, table.num_rows()):
		var row: PackedStringArray = table.get_row(r)
		if headers.size() > 0:
			# Named columns → dict per row
			var row_dict: Dictionary = {}
			for c in range(mini(headers.size(), row.size())):
				row_dict[headers[c]] = row[c]
			rows_array.append(row_dict)
		else:
			# No headers → array per row
			var row_arr: Array = []
			for cell in row:
				row_arr.append(cell)
			rows_array.append(row_arr)

	return JSON.stringify(rows_array, "\t")
