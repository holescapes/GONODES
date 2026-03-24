class_name LineSOP
extends GNSopBase
## Generates a line (series of points) as a line-strip mesh.
## Useful for curves, trails, and path visualization.


func _init() -> void:
	node_type = "line"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.SOP, "Line mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("points", 10, 2, 10000, "Num Points", "Number of vertices"))
	add_parameter(GNParameter.create_enum("direction",
		PackedStringArray(["X", "Y", "Z"]), 0, "Direction", "Line axis"))
	add_parameter(GNParameter.create_float("length", 2.0, 0.01, 1000.0, 0.1, "Length", "Total line length"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var num_pts: int = get_param_value("points")
	var dir_idx: int = get_param_value("direction")
	var total_len: float = get_param_value("length")
	var half: float = total_len * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in range(num_pts):
		var t: float = float(i) / max(num_pts - 1, 1)
		var pos: float = -half + t * total_len
		st.set_uv(Vector2(t, 0.0))
		match dir_idx:
			0:
				st.add_vertex(Vector3(pos, 0.0, 0.0))
			1:
				st.add_vertex(Vector3(0.0, pos, 0.0))
			2:
				st.add_vertex(Vector3(0.0, 0.0, pos))

	var arr_mesh := ArrayMesh.new()
	st.commit(arr_mesh)
	_cached_geo.set_mesh(arr_mesh)

	return _cached_geo
