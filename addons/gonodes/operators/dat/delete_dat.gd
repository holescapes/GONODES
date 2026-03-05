class_name DeleteDAT
extends GNDatBase
## Delete rows or columns from a table by index range (inclusive).


func _init() -> void:
	node_type = "delete"
	node_description = "Delete rows or columns from a table."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Table with deleted rows/columns")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Row", "Column"]), 0,
		"Mode", "Delete rows or columns"))
	add_parameter(GNParameter.create_int("start_index", 0, 0, null,
		"Start Index", "First row/column index to delete (0-based)"))
	add_parameter(GNParameter.create_int("end_index", 0, 0, null,
		"End Index", "Last row/column index to delete (inclusive, 0-based)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var out := _prepare_table()
	var in_dat: GNTableData = _get_input_dat(inputs, 0)
	if in_dat == null or not in_dat.is_table:
		return out

	var mode: int = get_param_value("mode")
	var start_idx: int = get_param_value("start_index")
	var end_idx: int = get_param_value("end_index")

	# Ensure valid range
	if end_idx < start_idx:
		end_idx = start_idx

	out.is_table = true
	out.has_header = in_dat.has_header

	if mode == 0:
		# ── Delete rows ─────────────────────────────────────────────────────
		# Convert data-row indices to raw table indices (skip header)
		var offset: int = 1 if in_dat.has_header else 0
		var raw_start: int = start_idx + offset
		var raw_end: int = end_idx + offset

		for row_idx in range(in_dat.table.size()):
			if row_idx >= raw_start and row_idx <= raw_end:
				continue  # Skip deleted rows
			out.table.append(in_dat.table[row_idx].duplicate())
	else:
		# ── Delete columns ──────────────────────────────────────────────────
		var clamped_start: int = maxi(start_idx, 0)
		var clamped_end: int = mini(end_idx, in_dat.num_cols() - 1)

		for row_idx in range(in_dat.table.size()):
			var src_row: PackedStringArray = in_dat.table[row_idx]
			var new_row := PackedStringArray()
			for c in range(src_row.size()):
				if c >= clamped_start and c <= clamped_end:
					continue  # Skip deleted columns
				new_row.append(src_row[c])
			out.table.append(new_row)

	return out
