class_name CircleSOP
extends GNSopBase
## Generates a circle or disc mesh.
## Can produce a filled disc (triangles) or a wire circle (line loop).


func _init() -> void:
	node_type = "circle"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Circle/disc mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("radius", 0.5, 0.01, 100.0, 0.01, "Radius", "Circle radius"))
	add_parameter(GNParameter.create_int("segments", 32, 3, 512, "Segments", "Number of edge segments"))
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Filled Disc", "Wire Circle"]), 0, "Type", "Filled disc or wire circle"))
	add_parameter(GNParameter.create_enum("orientation",
		PackedStringArray(["XZ (Horizontal)", "XY (Vertical)", "YZ (Side)"]), 0, "Orientation", "Plane orientation"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var radius: float = get_param_value("radius")
	var segments: int = get_param_value("segments")
	var filled: bool = get_param_value("type") == 0
	var orient: int = get_param_value("orientation")

	var st := SurfaceTool.new()

	if filled:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Center vertex
		st.set_uv(Vector2(0.5, 0.5))
		st.set_normal(_make_normal(orient))
		st.add_vertex(_make_point(0.0, 0.0, orient))

		# Perimeter vertices
		for i in range(segments + 1):
			var angle: float = TAU * float(i) / segments
			var x: float = cos(angle) * radius
			var y: float = sin(angle) * radius
			st.set_uv(Vector2(cos(angle) * 0.5 + 0.5, sin(angle) * 0.5 + 0.5))
			st.set_normal(_make_normal(orient))
			st.add_vertex(_make_point(x, y, orient))

		# Triangle indices (fan from center)
		for i in range(segments):
			st.add_index(0)
			st.add_index(i + 1)
			st.add_index(i + 2)
	else:
		st.begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in range(segments + 1):
			var angle: float = TAU * float(i) / segments
			var x: float = cos(angle) * radius
			var y: float = sin(angle) * radius
			st.set_uv(Vector2(float(i) / segments, 0.0))
			st.add_vertex(_make_point(x, y, orient))

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo


func _make_point(x: float, y: float, orient: int) -> Vector3:
	match orient:
		0: return Vector3(x, 0.0, y)  # XZ
		1: return Vector3(x, y, 0.0)  # XY
		2: return Vector3(0.0, x, y)  # YZ
		_: return Vector3(x, 0.0, y)


func _make_normal(orient: int) -> Vector3:
	match orient:
		0: return Vector3.UP
		1: return Vector3.BACK
		2: return Vector3.RIGHT
		_: return Vector3.UP
