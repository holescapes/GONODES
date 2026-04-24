class_name MeasureSOPNative
extends GNSopBase
## Native-accelerated geometry measurement — delegates to GNNativeMeasureSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "measure_native"
	if ClassDB.class_exists("GNNativeMeasureSop"):
		_processor = ClassDB.instantiate("GNNativeMeasureSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry to measure")
	add_output("out", GNFamily.Type.SOP, "Geometry with measurement attributes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("area", true,
		"Area", "Compute surface area"))
	add_parameter(GNParameter.create_bool("perimeter", true,
		"Perimeter", "Compute edge perimeter"))
	add_parameter(GNParameter.create_bool("curvature", false,
		"Curvature", "Compute mean curvature per vertex"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_geo := _require_input_geo(inputs)
	if not input_geo or not _processor:
		return null

	var mesh: ArrayMesh = input_geo.mesh
	if not mesh or mesh.get_surface_count() == 0:
		return input_geo

	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

	var result: Dictionary = _processor.process(vertices, indices)

	var out := _prepare_geo()
	out.mesh = mesh.duplicate()
	if get_param_value("area"):
		out.point_attribs["total_area"] = PackedFloat32Array([result.get("area", 0.0)])
	if get_param_value("perimeter"):
		out.point_attribs["total_perimeter"] = PackedFloat32Array([result.get("perimeter", 0.0)])
	if get_param_value("curvature"):
		out.point_attribs["curvature"] = result.get("curvature", PackedFloat32Array())
	return out
