class_name InsertDAT
extends GNDatBase
## Insert rows or columns into a table at a specified position.
## New cells are filled with a configurable fill value.


func _init() -> void:
	node_type = "insert"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Table with inserted rows/columns")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Row", "Column"]), 0,
		"Mode", "Insert rows or columns"))
	add_parameter(GNParameter.create_int("index", 0, 0, null,
		"Index", "Position to insert at (0-based data row or column index)"))
	add_parameter(GNParameter.create_int("count", 1, 1, 100,
		"Count", "Number of rows or columns to insert"))
	add_parameter(GNParameter.create_string("fill_value", "",
		"Fill Value", "Value to fill new cells with"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var in_dat: GNTableData = _get_input_dat(inputs, 0)
	if in_dat == null or not in_dat.is_table:
		return out

	var mode: int = get_param_value("mode")
	var idx: int = get_param_value("index")
	var count: int = get_param_value("count")
	var fill: String = get_param_value("fill_value")

	out.is_table = true
	out.has_header = in_dat.has_header
	var num_cols: int = in_dat.num_cols()

	if mode == 0:
		# ── Insert rows ─────────────────────────────────────────────────────
		# Copy all existing rows from source
		for row_idx in range(in_dat.table.size()):
			out.table.append(in_dat.table[row_idx].duplicate())

		# Calculate actual insertion point in the raw table array
		var insert_at: int = idx + (1 if in_dat.has_header else 0)
		insert_at = clampi(insert_at, 1 if in_dat.has_header else 0, out.table.size())

		for _i in range(count):
			var new_row := PackedStringArray()
			new_row.resize(num_cols)
			for c in range(num_cols):
				new_row[c] = fill
			out.table.insert(insert_at, new_row)
	else:
		# ── Insert columns ──────────────────────────────────────────────────
		var col_idx: int = clampi(idx, 0, num_cols)
		for row_idx in range(in_dat.table.size()):
			var src_row: PackedStringArray = in_dat.table[row_idx]
			var new_row := PackedStringArray()
			for c in range(src_row.size()):
				if c == col_idx:
					for _n in range(count):
						new_row.append(fill)
				new_row.append(src_row[c])
			# If inserting at the end
			if col_idx >= src_row.size():
				for _n in range(count):
					new_row.append(fill)
			out.table.append(new_row)

	return out
