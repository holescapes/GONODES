class_name TransposeDAT
extends GNNode
## Transposes a table — swaps rows and columns.
## Row 0 becomes Column 0, Column 0 becomes Row 0, etc.

var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "transpose"
	family = GNFamily.Type.DAT


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT)
	add_output("out", GNFamily.Type.DAT)


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	var in_dat: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if in_dat == null or not in_dat.is_table or in_dat.table.is_empty():
		return null

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var src_rows: int = in_dat.table.size()
	var src_cols: int = in_dat.num_cols()

	# Transposed dimensions: old cols become new rows
	for c in range(src_cols):
		var new_row := PackedStringArray()
		for r in range(src_rows):
			if c < in_dat.table[r].size():
				new_row.append(in_dat.table[r][c])
			else:
				new_row.append("")
		_cached_table.table.append(new_row)

	# First row of transposed table may serve as header (was first column)
	_cached_table.has_header = in_dat.has_header
	_cached_table.is_table = true
	return _cached_table
