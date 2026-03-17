class_name MergeDAT
extends GNDatBase
## Merges two DAT tables by appending rows or columns.
## In row mode: appends rows of input 2 below input 1.
## In column mode: appends columns of input 2 beside input 1.


func _init() -> void:
	node_type = "merge"
	node_description = "Merge two tables (append rows or columns)."


func _init_ports() -> void:
	add_input("in1", GNFamily.Type.DAT, false, "First table", "Input 1")
	add_input("in2", GNFamily.Type.DAT, false, "Second table", "Input 2")
	add_output("out", GNFamily.Type.DAT, "Merged table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Rows", "Columns"]), 0, "Merge Mode", "Merge direction"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in1: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	var in2: GNTableData = inputs[1] as GNTableData if inputs.size() > 1 and inputs[1] is GNTableData else null

	if in1 == null:
		return in2
	if in2 == null:
		return in1

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var mode_idx: int = get_param_value("mode")

	if mode_idx == 0:
		# Row merge — stack vertically
		_cached_table.has_header = in1.has_header
		_cached_table.is_table = true
		# Copy all rows from in1 (including header)
		for row in in1.table:
			_cached_table.table.append(row.duplicate())
		# Add data rows from in2 (skip header if present)
		var start_row: int = 1 if in2.has_header else 0
		for r in range(start_row, in2.table.size()):
			_cached_table.table.append(in2.table[r].duplicate())
	else:
		# Column merge — place side by side
		_cached_table.is_table = true
		var max_rows: int = maxi(in1.table.size(), in2.table.size())
		_cached_table.has_header = in1.has_header or in2.has_header
		for r in range(max_rows):
			var row := PackedStringArray()
			# Columns from in1
			if r < in1.table.size():
				row.append_array(in1.table[r])
			else:
				for _c in range(in1.num_cols()):
					row.append("")
			# Columns from in2
			if r < in2.table.size():
				row.append_array(in2.table[r])
			else:
				for _c in range(in2.num_cols()):
					row.append("")
			_cached_table.table.append(row)

	return _cached_table
