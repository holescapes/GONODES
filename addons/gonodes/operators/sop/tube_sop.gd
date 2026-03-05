class_name TubeSOP
extends GNSopBase
## Generates a tube (open cylinder) or pipe (with inner wall) mesh.
## Uses SurfaceTool with configurable radii, height, segments, and caps.


func _init() -> void:
	node_type = "tube"
	node_description = "Generate a tube or pipe mesh."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Tube mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius_outer", 0.5, 0.01, 50.0, 0.01,
		"Outer Radius", "Outer radius of the tube"))
	add_parameter(GNParameter.create_float("radius_inner", 0.3, 0.0, 50.0, 0.01,
		"Inner Radius", "Inner radius (0 = solid cylinder)"))
	add_parameter(GNParameter.create_float("height", 1.0, 0.01, 100.0, 0.01,
		"Height", "Tube height"))
	add_parameter(GNParameter.create_int("segments", 24, 3, 256, "Segments",
		"Radial segments"))
	add_parameter(GNParameter.create_int("rows", 1, 1, 100, "Rows",
		"Height subdivisions"))
	add_parameter(GNParameter.create_bool("caps", true, "",
		"Generate top and bottom caps"))
	add_parameter(GNParameter.create_enum("orientation",
		PackedStringArray(["Y (Up)", "X", "Z"]), 0, "", "Tube axis"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var r_out: float = get_param_value("radius_outer")
	var r_in: float = get_param_value("radius_inner")
	var h: float = get_param_value("height")
	var segs: int = maxi(get_param_value("segments"), 3)
	var rows: int = maxi(get_param_value("rows"), 1)
	var do_caps: bool = get_param_value("caps")
	var orient: int = get_param_value("orientation")
	var has_inner: bool = r_in > 0.001

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_h: float = h * 0.5

	# Outer wall
	_build_cylinder_wall(st, r_out, half_h, segs, rows, orient, false)

	# Inner wall (reversed normals)
	if has_inner:
		_build_cylinder_wall(st, r_in, half_h, segs, rows, orient, true)

	# Caps
	if do_caps:
		_build_cap(st, r_out, r_in if has_inner else 0.0, half_h, segs, orient, true)   # Top
		_build_cap(st, r_out, r_in if has_inner else 0.0, -half_h, segs, orient, false)  # Bottom

	st.generate_normals()
	st.generate_tangents()

	var mesh := ArrayMesh.new()
	st.commit(mesh)
	_cached_geo.set_mesh(mesh)
	return _cached_geo


func _build_cylinder_wall(st: SurfaceTool, radius: float, half_h: float,
		segs: int, rows: int, orient: int, invert: bool) -> void:
	for row in range(rows):
		var y0: float = lerpf(-half_h, half_h, float(row) / rows)
		var y1: float = lerpf(-half_h, half_h, float(row + 1) / rows)
		var v0: float = float(row) / rows
		var v1: float = float(row + 1) / rows

		for seg in range(segs):
			var a0: float = TAU * float(seg) / segs
			var a1: float = TAU * float(seg + 1) / segs
			var u0: float = float(seg) / segs
			var u1: float = float(seg + 1) / segs

			var p00: Vector3 = _make_point(cos(a0) * radius, y0, sin(a0) * radius, orient)
			var p10: Vector3 = _make_point(cos(a1) * radius, y0, sin(a1) * radius, orient)
			var p01: Vector3 = _make_point(cos(a0) * radius, y1, sin(a0) * radius, orient)
			var p11: Vector3 = _make_point(cos(a1) * radius, y1, sin(a1) * radius, orient)

			if invert:
				st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
				st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
				st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
				st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
				st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
				st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
			else:
				st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
				st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
				st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
				st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
				st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
				st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)


func _build_cap(st: SurfaceTool, r_out: float, r_in: float, y: float,
		segs: int, orient: int, top: bool) -> void:
	for seg in range(segs):
		var a0: float = TAU * float(seg) / segs
		var a1: float = TAU * float(seg + 1) / segs

		var o0: Vector3 = _make_point(cos(a0) * r_out, y, sin(a0) * r_out, orient)
		var o1: Vector3 = _make_point(cos(a1) * r_out, y, sin(a1) * r_out, orient)

		if r_in > 0.001:
			# Annular cap
			var i0: Vector3 = _make_point(cos(a0) * r_in, y, sin(a0) * r_in, orient)
			var i1: Vector3 = _make_point(cos(a1) * r_in, y, sin(a1) * r_in, orient)

			if top:
				st.set_uv(Vector2(0, 0)); st.add_vertex(o0)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
				st.set_uv(Vector2(0, 1)); st.add_vertex(i0)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
				st.set_uv(Vector2(1, 1)); st.add_vertex(i1)
				st.set_uv(Vector2(0, 1)); st.add_vertex(i0)
			else:
				st.set_uv(Vector2(0, 0)); st.add_vertex(o0)
				st.set_uv(Vector2(0, 1)); st.add_vertex(i0)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
				st.set_uv(Vector2(0, 1)); st.add_vertex(i0)
				st.set_uv(Vector2(1, 1)); st.add_vertex(i1)
		else:
			# Solid disc cap (fan to centre)
			var centre: Vector3 = _make_point(0.0, y, 0.0, orient)
			if top:
				st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(centre)
				st.set_uv(Vector2(0, 0)); st.add_vertex(o0)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
			else:
				st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(centre)
				st.set_uv(Vector2(1, 0)); st.add_vertex(o1)
				st.set_uv(Vector2(0, 0)); st.add_vertex(o0)


func _make_point(x: float, y: float, z: float, orient: int) -> Vector3:
	match orient:
		1: return Vector3(y, z, x)  # X axis
		2: return Vector3(x, z, y)  # Z axis
		_: return Vector3(x, y, z)  # Y axis (default)
