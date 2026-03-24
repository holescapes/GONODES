class_name EvaluateDAT
extends GNDatBase
## Evaluates expressions in each cell of the input table.
## Cells containing expressions (starting with '=') are evaluated.
## Non-expression cells pass through unchanged.
## Supports basic math: =1+2, =3*4, etc. via Godot's Expression class.

var _expr: Expression = null


func _init() -> void:
	node_type = "evaluate"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table with expressions")
	add_output("out", GNFamily.Type.DAT, "Evaluated table")


func _init_parameters() -> void:
	pass


func _cook(inputs: Array[GNData]) -> GNData:
	var in_dat: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if in_dat == null or not in_dat.is_table:
		return null

	if _cached_table == null:
		_cached_table = GNTableData.new()
	_cached_table.table.clear()
	_cached_table.has_header = in_dat.has_header
	_cached_table.is_table = true

	if _expr == null:
		_expr = Expression.new()

	var start_row: int = 0
	if in_dat.has_header and not in_dat.table.is_empty():
		_cached_table.table.append(in_dat.table[0].duplicate())
		start_row = 1

	for r in range(start_row, in_dat.table.size()):
		var row := PackedStringArray()
		for c in range(in_dat.table[r].size()):
			var cell_val: String = in_dat.table[r][c]
			if cell_val.begins_with("="):
				var expr_text: String = cell_val.substr(1)
				var err := _expr.parse(expr_text)
				if err == OK:
					var result: Variant = _expr.execute()
					if not _expr.has_execute_failed():
						row.append(str(result))
					else:
						row.append("#ERR")
				else:
					row.append("#ERR")
			else:
				row.append(cell_val)
		_cached_table.table.append(row)

	return _cached_table
