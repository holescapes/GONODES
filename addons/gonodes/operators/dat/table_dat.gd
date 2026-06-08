class_name TableDAT
extends GNDatBase
## Manual editable data table.
##
## Creates a table with configurable rows and columns.
## Cells are populated from a multi-line string parameter (CSV-like).
## Also supports appending rows from an input DAT and setting
## individual cells via the row/col/value parameters.

func _init() -> void:
	node_type = "table"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Optional DAT to append/merge", "In")
	add_output("out", GNFamily.Type.DAT, "Table output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("rows", 4, 0, 10000, "Rows", "Number of data rows"))
	add_parameter(GNParameter.create_int("cols", 3, 1, 100, "Cols", "Number of columns"))
	add_parameter(GNParameter.create_string("headers", "name,value,weight",
		"Headers", "Comma-separated column headers"))
	add_parameter(GNParameter.create_string("data", "The data string",
		"Data", "Cell data: one row per line, comma-separated values"))
	add_parameter(GNParameter.create_bool("merge_input", false,
		"Merge Input", "Append input DAT rows after this table's data"))


func _cook(inputs: Array[GNData]) -> GNData:
	var num_rows: int = get_param_value("rows")
	var num_cols: int = get_param_value("cols")
	var headers_str: String = get_param_value("headers")
	var data_str: String = get_param_value("data")
	var merge: bool = get_param_value("merge_input")

	var output: GNTableData = _prepare_table()
	output.has_header = true
	output.is_table = true

	# Parse headers
	var headers := PackedStringArray()
	for h: String in headers_str.split(","):
		headers.append(h.strip_edges())
	# Pad or trim to num_cols
	while headers.size() < num_cols:
		headers.append("c%d" % headers.size())
	if headers.size() > num_cols:
		headers.resize(num_cols)

	output.table.append(headers)

	# Parse data string — each line is a row, comma-separated
	if not data_str.strip_edges().is_empty():
		var lines: PackedStringArray = data_str.split("\n")
		for line: String in lines:
			if line.strip_edges().is_empty():
				continue
			var cells := PackedStringArray()
			for cell: String in line.split(","):
				cells.append(cell.strip_edges())
			# Pad to num_cols
			while cells.size() < num_cols:
				cells.append("")
			if cells.size() > num_cols:
				cells.resize(num_cols)
			output.table.append(cells)

	# Fill remaining rows with empty cells
	var current_data_rows: int = output.table.size() - 1  # exclude header
	while current_data_rows < num_rows:
		var empty_row := PackedStringArray()
		empty_row.resize(num_cols)
		for i in range(num_cols):
			empty_row[i] = ""
		output.table.append(empty_row)
		current_data_rows += 1

	# Merge input DAT if connected
	if merge:
		var input_dat: GNTableData = _get_input_dat(inputs, 0)
		if input_dat != null and not input_dat.table.is_empty():
			var start_row: int = 1 if input_dat.has_header else 0
			for r in range(start_row, input_dat.table.size()):
				var row: PackedStringArray = input_dat.table[r]
				# Pad/trim to match our column count
				var adjusted := PackedStringArray()
				adjusted.resize(num_cols)
				for c in range(num_cols):
					adjusted[c] = row[c] if c < row.size() else ""
				output.table.append(adjusted)

	return output
