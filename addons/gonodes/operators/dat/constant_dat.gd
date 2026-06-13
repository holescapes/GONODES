class_name ConstantDAT
extends GNDatBase
## Outputs a table with user-defined constant values.
## Supports up to 4 rows × 4 columns of hand-entered data.


func _init() -> void:
	node_type = "constant"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.DAT, "Table output")


func _init_parameters() -> void:
	# Column headers
	add_parameter(GNParameter.create_string("col0", "name", "Column 0", "Header name for column 0"))
	add_parameter(GNParameter.create_string("col1", "value", "Column 1", "Header name for column 1"))
	add_parameter(GNParameter.create_string("col2", "", "Column 2", "Header for column 2 (empty = skip)"))
	add_parameter(GNParameter.create_string("col3", "", "Column 3", "Header for column 3 (empty = skip)"))
	# Row data (4 rows × 4 cols)
	for r in range(4):
		for c in range(4):
			add_parameter(GNParameter.create_string("r%dc%d" % [r, c], "", "Row %d Col %d" % [r, c], "Cell value"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_table == null:
		_cached_table = GNTableData.new()

	# Build headers
	var headers := PackedStringArray()
	var num_cols: int = 0
	for c in range(4):
		var h: String = get_param_value("col%d" % c)
		if h.is_empty() and c >= 2:
			break
		headers.append(h)
		num_cols = c + 1

	_cached_table.set_headers(headers)

	# Build data rows — skip empty rows
	for r in range(4):
		var row := PackedStringArray()
		var has_content: bool = false
		for c in range(num_cols):
			var val: String = get_param_value("r%dc%d" % [r, c])
			row.append(val)
			if not val.is_empty():
				has_content = true
		if has_content:
			_cached_table.append_row(row)

	return _cached_table


## Called by GNTableRenderer when the user edits a cell in the viewer.
func table_cell_edited(row: int, col: int, value: String) -> void:
	# Columns 0-3 map to r{row}c{col} params
	if row < 0 or row > 3 or col < 0 or col > 3:
		return
	set_param_value("r%dc%d" % [row, col], value)
	mark_dirty()
