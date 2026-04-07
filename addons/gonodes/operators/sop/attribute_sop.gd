class_name AttributeSOP
extends GNSopBase
## Creates or modifies per-vertex attributes (stored in GNGeoData.point_attribs).
## Can set from expressions, copy from position/normal channels, or set constant.
## Expression vars: px, py, pz, i, n, t, dt, frame.
## Useful for driving CopySOP pscale, color, age, etc.


func _init() -> void:
	node_type = "attribute"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with attributes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("name", "pscale",
		"Attribute Name", "Name of the point attribute to create/modify"))
	add_parameter(GNParameter.create_enum("source",
		PackedStringArray(["Constant", "Expression", "Position X", "Position Y",
			"Position Z", "Normal Y", "UV U", "Random"]),
		0, "", "Value source"))
	add_parameter(GNParameter.create_float("value", 1.0, null, null, 0.01,
		"Constant Value", "Value to set (Constant mode)"))
	add_parameter(GNParameter.create_string("expression", "sin(float(i) / float(n) * 6.28)",
		"Expression", "Per-vertex expression — vars: px,py,pz,i,n,t,dt,frame"))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", "Random seed"))
	add_parameter(GNParameter.create_float("rand_min", 0.0, null, null, 0.01, "Random Min", ""))
	add_parameter(GNParameter.create_float("rand_max", 1.0, null, null, 0.01, "Random Max", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _require_input_geo(inputs)
	if in_geo == null:
		return null

	# Duplicate input geometry
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	# Copy mesh
	if in_geo.mesh != null:
		_cached_geo.set_mesh(in_geo.mesh.duplicate() as ArrayMesh)

	# Copy existing attribs
	for key in in_geo.point_attribs:
		_cached_geo.point_attribs[key] = in_geo.point_attribs[key].duplicate()

	var attr_name: String = get_param_value("name")
	var source: int = get_param_value("source")
	var const_val: float = get_param_value("value")
	var expr_str: String = get_param_value("expression")
	var seed_val: int = get_param_value("seed")
	var rand_min: float = get_param_value("rand_min")
	var rand_max: float = get_param_value("rand_max")
	var t: float = elapsed_time
	var dt_val: float = current_delta
	var frame_val: float = float(current_frame)

	# Collect all vertex positions for expression evaluation
	var all_verts := PackedVector3Array()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			all_verts.append_array(arrays[Mesh.ARRAY_VERTEX])

	var vert_count: int = all_verts.size()
	var result := PackedFloat32Array()
	result.resize(vert_count)

	match source:
		0:  # Constant
			result.fill(const_val)

		1:  # Expression
			var expr := Expression.new()
			var var_names := PackedStringArray(["px", "py", "pz", "i", "n", "t", "dt", "frame"])
			if expr.parse(expr_str, var_names) != OK:
				GNLogger.warn("AttributeSOP", "'%s' — parse error: %s" % [id, expr.get_error_text()])
				return _cached_geo
			for i in range(vert_count):
				var p: Vector3 = all_verts[i]
				var vals: Array = [p.x, p.y, p.z, float(i), float(vert_count), t, dt_val, frame_val]
				var res = expr.execute(vals, self, false)
				if res is float:
					result[i] = res
				elif res is int:
					result[i] = float(res)
				else:
					result[i] = 0.0

		2:  # Position X
			for i in range(vert_count):
				result[i] = all_verts[i].x
		3:  # Position Y
			for i in range(vert_count):
				result[i] = all_verts[i].y
		4:  # Position Z
			for i in range(vert_count):
				result[i] = all_verts[i].z

		5:  # Normal Y
			var all_normals := PackedVector3Array()
			for s in range(in_geo.mesh.get_surface_count()):
				var arrays: Array = in_geo.mesh.surface_get_arrays(s)
				if arrays[Mesh.ARRAY_NORMAL] != null:
					all_normals.append_array(arrays[Mesh.ARRAY_NORMAL])
				else:
					var pad := PackedVector3Array()
					pad.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
					pad.fill(Vector3.UP)
					all_normals.append_array(pad)
			for i in range(vert_count):
				result[i] = all_normals[i].y if i < all_normals.size() else 1.0

		6:  # UV U
			var all_uvs := PackedVector2Array()
			for s in range(in_geo.mesh.get_surface_count()):
				var arrays: Array = in_geo.mesh.surface_get_arrays(s)
				if arrays[Mesh.ARRAY_TEX_UV] != null:
					all_uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
				else:
					var pad := PackedVector2Array()
					pad.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
					all_uvs.append_array(pad)
			for i in range(vert_count):
				result[i] = all_uvs[i].x if i < all_uvs.size() else 0.0

		7:  # Random
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_val
			for i in range(vert_count):
				result[i] = rng.randf_range(rand_min, rand_max)

	_cached_geo.set_point_attrib(attr_name, result)
	return _cached_geo
