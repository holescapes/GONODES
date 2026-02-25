class_name GridSOP
extends GNSopBase
## Generates a planar grid mesh using Godot's SurfaceTool.
## Configurable rows, columns, and size — produces a subdivided quad
## suitable for displacement, terrain, or wave effects.


func _init() -> void:
	node_type = "grid"
	node_description = "Generate a subdivided planar grid."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Grid mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("size_x", 2.0, 0.01, 100.0, 0.1, "Size X", "Grid width"))
	add_parameter(GNParameter.create_float("size_z", 2.0, 0.01, 100.0, 0.1, "Size Z", "Grid depth"))
	add_parameter(GNParameter.create_int("rows", 10, 1, 500, "Rows", "Row subdivisions"))
	add_parameter(GNParameter.create_int("cols", 10, 1, 500, "Columns", "Column subdivisions"))
	add_parameter(GNParameter.create_enum("orientation",
		PackedStringArray(["XZ (Horizontal)", "XY (Vertical)", "YZ (Side)"]), 0, "Orientation", "Plane orientation"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var sx: float = get_param_value("size_x")
	var sz: float = get_param_value("size_z")
	var rows: int = get_param_value("rows")
	var cols: int = get_param_value("cols")
	var orient: int = get_param_value("orientation")

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_x: float = sx * 0.5
	var half_z: float = sz * 0.5

	# Generate vertices
	for r in range(rows + 1):
		for c in range(cols + 1):
			var u: float = float(c) / cols
			var v: float = float(r) / rows
			var px: float = -half_x + u * sx
			var pz: float = -half_z + v * sz

			st.set_uv(Vector2(u, v))

			match orient:
				0:  # XZ
					st.set_normal(Vector3.UP)
					st.add_vertex(Vector3(px, 0.0, pz))
				1:  # XY
					st.set_normal(Vector3.BACK)
					st.add_vertex(Vector3(px, pz, 0.0))
				2:  # YZ
					st.set_normal(Vector3.RIGHT)
					st.add_vertex(Vector3(0.0, px, pz))

	# Generate triangle indices
	for r in range(rows):
		for c in range(cols):
			var i: int = r * (cols + 1) + c
			st.add_index(i)
			st.add_index(i + cols + 1)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols + 1)
			st.add_index(i + cols + 2)

	st.generate_tangents()
	_cached_geo.set_mesh(ArrayMesh.new())
	_cached_geo.set_from_surface_tool(st)

	return _cached_geo
