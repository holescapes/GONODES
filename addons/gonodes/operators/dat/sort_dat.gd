class_name SortDAT
extends GNNode
## Sorts the rows of a table by a specified column.
## Supports ascending/descending and alphabetic/numeric sort.

var _cached_table: GNTableData = null


func _init() -> void:
	node_type = "sort"
	family = GNFamily.Type.DAT
	node_description = "Sort table rows by a column."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Sorted table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("sort_col", 0, 0, null, "Sort Column", "Column index to sort by"))
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["Ascending", "Descending"]), 0, "Order", "Sort direction"))
	add_parameter(GNParameter.create_enum("sort_type",
		PackedStringArray(["Alphabetic", "Numeric"]), 0, "Sort Type", "Comparison method"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_dat: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if in_dat == null or not in_dat.is_table or in_dat.table.is_empty():
		return null

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()

	var sort_col: int = get_param_value("sort_col")
	var descending: bool = get_param_value("order") == 1
	var numeric: bool = get_param_value("sort_type") == 1

	# Copy header
	_cached_table.has_header = in_dat.has_header
	_cached_table.is_table = true
	if in_dat.has_header and not in_dat.table.is_empty():
		_cached_table.table.append(in_dat.table[0].duplicate())

	# Collect data rows
	var data_start: int = 1 if in_dat.has_header else 0
	var rows: Array = []
	for r in range(data_start, in_dat.table.size()):
		rows.append(in_dat.table[r].duplicate())

	# Sort
	if numeric:
		rows.sort_custom(func(a: PackedStringArray, b: PackedStringArray) -> bool:
			var va: float = a[sort_col].to_float() if sort_col < a.size() else 0.0
			var vb: float = b[sort_col].to_float() if sort_col < b.size() else 0.0
			return va < vb if not descending else va > vb
		)
	else:
		rows.sort_custom(func(a: PackedStringArray, b: PackedStringArray) -> bool:
			var sa: String = a[sort_col] if sort_col < a.size() else ""
			var sb: String = b[sort_col] if sort_col < b.size() else ""
			return sa < sb if not descending else sa > sb
		)

	for row in rows:
		_cached_table.table.append(row)

	return _cached_table
