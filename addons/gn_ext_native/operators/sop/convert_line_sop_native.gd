class_name ConvertLineSOPNative
extends GNSopBase
## Native-accelerated line conversion — delegates to GNNativeConvertLineSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "convertline_native"
	if ClassDB.class_exists("GNNativeConvertLineSop"):
		_processor = ClassDB.instantiate("GNNativeConvertLineSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input line geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Converted line geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("target",
		PackedStringArray(["Polyline", "Bezier (Cubic)", "Subdivision"]), 0,
		"Target Type", "Line conversion mode"))
	add_parameter(GNParameter.create_int("segments", 16, 2, 256,
		"Segments", "Number of output segments (bezier) or iterations (subdivision)"))
	add_parameter(GNParameter.create_float("tension", 0.5, 0.0, 1.0, 0.01,
		"Tension", "Spline tension (bezier mode only)"))
	add_parameter(GNParameter.create_bool("closed", false,
		"Close", "Close the output curve"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_geo := _require_input_geo(inputs)
	if not input_geo or not _processor:
		return null

	var mesh: ArrayMesh = input_geo.mesh
	if not mesh or mesh.get_surface_count() == 0:
		return input_geo

	# Extract all points
	var points := PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		points.append_array(verts)

	var mode: int = get_param_value("target")
	var segments: int = get_param_value("segments")
	var tension: float = get_param_value("tension")
	var closed: bool = get_param_value("closed")

	var result: PackedVector3Array = _processor.process(points, mode, segments, tension, closed)

	var out := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for v in result:
		st.add_vertex(v)
	out.mesh = st.commit()
	return out
