class_name ResampleSOPNative
extends GNSopBase
## Native-accelerated polyline resampling — delegates to GNNativeResampleSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "resample_native"
	if ClassDB.class_exists("GNNativeResampleSop"):
		_processor = ClassDB.instantiate("GNNativeResampleSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry to resample")
	add_output("out", GNFamily.Type.SOP, "Resampled geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Even", "Length"]), 0,
		"Mode", "Resampling mode"))
	add_parameter(GNParameter.create_int("count", 32, 2, 10000,
		"Point Count", "Target number of output points (Even mode)"))
	add_parameter(GNParameter.create_float("segment_length", 0.1, 0.001, 100.0, 0.001,
		"Segment Length", "Target segment length (Length mode)"))
	add_parameter(GNParameter.create_bool("close", false,
		"Close Curves", "Close output curves"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_geo := _require_input_geo(inputs)
	if not input_geo or not _processor:
		return null

	var mesh: ArrayMesh = input_geo.mesh
	if not mesh or mesh.get_surface_count() == 0:
		return input_geo

	# Extract points from line geometry
	var points := PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		points.append_array(arrays[Mesh.ARRAY_VERTEX])

	var mode: int = get_param_value("mode")
	var seg_len: float = get_param_value("segment_length")
	var count: int = get_param_value("count")
	var closed: bool = get_param_value("close")

	var result: PackedVector3Array = _processor.process(points, mode, seg_len, count, closed)

	var out := _prepare_geo()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	for v in result:
		st.add_vertex(v)
	out.mesh = st.commit()
	return out
