class_name MergeDAT
extends GNDatBase
## Merges two DAT tables by appending rows or columns.
## In row mode: appends rows of input 2 below input 1.
## In column mode: appends columns of input 2 beside input 1.


func _init() -> void:
	node_type = "merge"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Table to merge", "Input")
	add_output("out", GNFamily.Type.DAT, "Merged table", "Out")
	_enable_dynamic_inputs(GNFamily.Type.DAT, "in", "Input")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Rows", "Columns"]), 0, "Merge Mode", "Merge direction"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Collect all valid table inputs
	var tables: Array[GNTableData] = []
	for inp in inputs:
		var td := inp as GNTableData if inp is GNTableData else null
		if td != null:
			tables.append(td)

	if tables.is_empty():
		return null
	if tables.size() == 1:
		return tables[0]

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var mode_idx: int = get_param_value("mode")

	if mode_idx == 0:
		# Row merge — stack vertically
		_cached_table.has_header = tables[0].has_header
		_cached_table.is_table = true
		for row in tables[0].table:
			_cached_table.table.append(row.duplicate())
		for i in range(1, tables.size()):
			var t: GNTableData = tables[i]
			var start_row: int = 1 if t.has_header else 0
			for r in range(start_row, t.table.size()):
				_cached_table.table.append(t.table[r].duplicate())
	else:
		# Column merge — place side by side
		_cached_table.is_table = true
		var max_rows: int = 0
		for t in tables:
			max_rows = maxi(max_rows, t.table.size())
		_cached_table.has_header = tables[0].has_header
		for r in range(max_rows):
			var row := PackedStringArray()
			for t in tables:
				if r < t.table.size():
					row.append_array(t.table[r])
				else:
					for _c in range(t.num_cols()):
						row.append("")
			_cached_table.table.append(row)

	return _cached_table
