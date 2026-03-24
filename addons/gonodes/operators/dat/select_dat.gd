class_name SelectDAT
extends GNDatBase
## Selects specific rows and/or columns from an input table.
## Supports range-based row/column selection.


func _init() -> void:
	node_type = "select"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Selected subset")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("row_start", 0, 0, null, "Row Start", "First row index"))
	add_parameter(GNParameter.create_int("row_end", -1, -1, null, "Row End", "Last row index (-1 = end)"))
	add_parameter(GNParameter.create_int("col_start", 0, 0, null, "Col Start", "First column index"))
	add_parameter(GNParameter.create_int("col_end", -1, -1, null, "Col End", "Last column index (-1 = end)"))
	add_parameter(GNParameter.create_bool("include_header", true, "Include Header", "Keep header row in output"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_dat: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if in_dat == null or not in_dat.is_table:
		return null

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var r_start: int = get_param_value("row_start")
	var r_end: int = get_param_value("row_end")
	var c_start: int = get_param_value("col_start")
	var c_end: int = get_param_value("col_end")
	var inc_header: bool = get_param_value("include_header")

	var total_rows: int = in_dat.num_rows()
	var total_cols: int = in_dat.num_cols()

	if r_end < 0:
		r_end = total_rows - 1
	r_end = mini(r_end, total_rows - 1)
	if c_end < 0:
		c_end = total_cols - 1
	c_end = mini(c_end, total_cols - 1)

	# Extract header if requested
	if inc_header and in_dat.has_header:
		var header := PackedStringArray()
		var src_headers: PackedStringArray = in_dat.get_headers()
		for c in range(c_start, c_end + 1):
			header.append(src_headers[c] if c < src_headers.size() else "")
		_cached_table.set_headers(header)
	else:
		_cached_table.has_header = false

	# Extract selected rows and columns
	for r in range(r_start, r_end + 1):
		var row := PackedStringArray()
		for c in range(c_start, c_end + 1):
			row.append(in_dat.cell(r, c))
		_cached_table.append_row(row)

	_cached_table.is_table = true
	return _cached_table
