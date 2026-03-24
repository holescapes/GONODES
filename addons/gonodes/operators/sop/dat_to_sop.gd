class_name DATtoSOP
extends GNSopBase
## Converts DAT table data into SOP geometry.
##
## Two modes:
##   • Points — Each row is a point.  Columns named x/y/z (or px/py/pz)
##     provide position.  Missing columns default to 0.
##   • Lines — Consecutive pairs of rows become line segments
##     (PRIMITIVE_LINES).
##
## Additional columns can be stored as point attributes on the output geo.

func _init() -> void:
	node_type = "dat_to_sop"
	node_description = "Convert DAT table rows to SOP points."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, true, "Source DAT table")
	add_output("out", GNFamily.Type.SOP, "Generated point geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Points", "Lines"]),
		0, "Mode", "Output primitive type"))
	add_parameter(GNParameter.create_int("max_rows", 10000, 1, 1000000,
		"Max Rows", "Maximum table rows to process"))


func _cook(inputs: Array[GNData]) -> GNData:
	var dat: GNTableData = inputs[0] as GNTableData if inputs.size() > 0 and inputs[0] is GNTableData else null
	if dat == null or dat.table.is_empty():
		return null

	var mode: int = get_param_value("mode")
	var max_rows: int = get_param_value("max_rows")

	var table: Array = dat.table
	var headers: PackedStringArray = PackedStringArray()
	var data_start: int = 0

	if dat.has_header and table.size() > 0:
		for h in table[0]:
			headers.append(str(h).strip_edges().to_lower())
		data_start = 1

	# Find position column indices
	var col_x: int = _find_column(headers, ["x", "px", "posx"])
	var col_y: int = _find_column(headers, ["y", "py", "posy"])
	var col_z: int = _find_column(headers, ["z", "pz", "posz"])

	# If no header match, try first 3 columns
	if col_x == -1 and headers.size() >= 1:
		col_x = 0
	if col_y == -1 and headers.size() >= 2:
		col_y = 1
	if col_z == -1 and headers.size() >= 3:
		col_z = 2

	var verts := PackedVector3Array()
	var extra_attribs := {}  # name -> PackedFloat32Array

	# Identify extra numeric columns for point attributes
	var extra_cols: Array[int] = []
	var extra_names: PackedStringArray = PackedStringArray()
	for hi in range(headers.size()):
		if hi == col_x or hi == col_y or hi == col_z:
			continue
		extra_cols.append(hi)
		extra_names.append(headers[hi] if hi < headers.size() else ("col%d" % hi))
		extra_attribs[extra_names[extra_names.size() - 1]] = PackedFloat32Array()

	var rows_processed: int = 0
	for ri in range(data_start, table.size()):
		if rows_processed >= max_rows:
			break
		var row: Array = table[ri]

		var x: float = _safe_float(row, col_x)
		var y: float = _safe_float(row, col_y)
		var z: float = _safe_float(row, col_z)
		verts.append(Vector3(x, y, z))

		for ei in range(extra_cols.size()):
			var val: float = _safe_float(row, extra_cols[ei])
			extra_attribs[extra_names[ei]].append(val)

		rows_processed += 1

	if verts.is_empty():
		return null

	var out := _prepare_geo()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts

	var prim_type: int = Mesh.PRIMITIVE_POINTS
	if mode == 1 and verts.size() >= 2:
		prim_type = Mesh.PRIMITIVE_LINES
		# Ensure even vertex count for line pairs
		if verts.size() % 2 != 0:
			verts = verts.slice(0, verts.size() - 1)
			arrays[Mesh.ARRAY_VERTEX] = verts

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(prim_type, arrays)
	out.set_mesh(mesh)

	# Store extra attribs
	for attr_name in extra_attribs:
		var arr: PackedFloat32Array = extra_attribs[attr_name]
		if arr.size() == verts.size():
			out.set_point_attrib(attr_name, arr)

	return out


static func _find_column(headers: PackedStringArray, aliases: Array) -> int:
	for ai in range(aliases.size()):
		for hi in range(headers.size()):
			if headers[hi] == aliases[ai]:
				return hi
	return -1


static func _safe_float(row: Array, col: int) -> float:
	if col < 0 or col >= row.size():
		return 0.0
	var val = row[col]
	if val is float or val is int:
		return float(val)
	if val is String:
		if val.is_valid_float():
			return val.to_float()
	return 0.0
