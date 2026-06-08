class_name PointSOP
extends GNSopBase
## Applies per-vertex position expressions using Godot's Expression class.
## Variables: px, py, pz (position), nx, ny, nz (normal), u, v (UV),
## i (vertex index), n (vertex count), t (time), dt (delta), frame.


func _init() -> void:
	node_type = "point"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Modified geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("expr_x", "px",
		"Position X expression", "Expression for output X position"))
	add_parameter(GNParameter.create_string("expr_y", "py",
		"Position Y expression", "Expression for output Y position"))
	add_parameter(GNParameter.create_string("expr_z", "pz",
		"Position Z expression", "Expression for output Z position"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "Enable recompute normals",
		"Recompute normals after modification"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var expr_x_str: String = get_param_value("expr_x")
	var expr_y_str: String = get_param_value("expr_y")
	var expr_z_str: String = get_param_value("expr_z")
	var recompute: bool = get_param_value("recompute_normals")

	var var_names := PackedStringArray(["px", "py", "pz", "nx", "ny", "nz",
		"u", "v", "i", "n", "t", "dt", "frame"])

	var expr_x := Expression.new()
	var expr_y := Expression.new()
	var expr_z := Expression.new()

	if expr_x.parse(expr_x_str, var_names) != OK:
		GNLogger.warn("PointSOP", "'%s' — X parse error: %s" % [id, expr_x.get_error_text()])
		return null
	if expr_y.parse(expr_y_str, var_names) != OK:
		GNLogger.warn("PointSOP", "'%s' — Y parse error: %s" % [id, expr_y.get_error_text()])
		return null
	if expr_z.parse(expr_z_str, var_names) != OK:
		GNLogger.warn("PointSOP", "'%s' — Z parse error: %s" % [id, expr_z.get_error_text()])
		return null

	var t: float = elapsed_time
	var dt_val: float = current_delta
	var frame_val: float = float(current_frame)
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		if arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var vcount: int = verts.size()
		var new_verts := PackedVector3Array()
		new_verts.resize(vcount)

		for vi in range(vcount):
			var p: Vector3 = verts[vi]
			var nm: Vector3 = normals[vi] if vi < normals.size() else Vector3.UP
			var uv: Vector2 = uvs[vi] if vi < uvs.size() else Vector2.ZERO

			var vals: Array = [p.x, p.y, p.z, nm.x, nm.y, nm.z,
				uv.x, uv.y, float(vi), float(vcount), t, dt_val, frame_val]

			var rx = expr_x.execute(vals, self, false)
			var ry = expr_y.execute(vals, self, false)
			var rz = expr_z.execute(vals, self, false)

			new_verts[vi] = Vector3(
				_to_float(rx, p.x),
				_to_float(ry, p.y),
				_to_float(rz, p.z))

		arrays[Mesh.ARRAY_VERTEX] = new_verts

		if recompute and prim == Mesh.PRIMITIVE_TRIANGLES:
			var st := SurfaceTool.new()
			st.begin(prim)
			_feed_st(st, arrays)
			st.generate_normals()
			st.generate_tangents()
			st.commit(new_mesh)
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	return _cached_geo


func _to_float(val, fallback: float) -> float:
	if val is float:
		return val
	elif val is int:
		return float(val)
	return fallback


func _feed_st(st: SurfaceTool, arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	for i in range(verts.size()):
		if i < uvs.size():
			st.set_uv(uvs[i])
		st.add_vertex(verts[i])
	for idx in indices:
		st.add_index(idx)
