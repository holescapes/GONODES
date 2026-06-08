class_name SOPtoCHOPNative
extends GNChopBase
## Native-accelerated SOP→CHOP — delegates to GNNativeSopToChop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "soptochop_native"
	node_description = "Extract vertex attributes as CHOP channels — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSopToChop"):
		_processor = ClassDB.instantiate("GNNativeSopToChop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.CHOP, "Attribute channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("attribute",
		PackedStringArray(["Position", "Normal", "UV"]), 0,
		"Attribute", "Which vertex attribute to extract"))
	add_parameter(GNParameter.create_int("max_points", 1000, 1, 100000,
		"Max Points", "Maximum number of points to process"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry() or not _processor:
		return null

	var attrib: int = get_param_value("attribute")
	var max_pts: int = get_param_value("max_points")

	var result: Dictionary = {}

	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		match attrib:
			0:  # Position
				if arrays[Mesh.ARRAY_VERTEX] != null:
					result = _processor.process_positions(arrays[Mesh.ARRAY_VERTEX], max_pts)
			1:  # Normal
				if arrays[Mesh.ARRAY_NORMAL] != null:
					result = _processor.process_normals(arrays[Mesh.ARRAY_NORMAL], max_pts)
			2:  # UV
				if arrays[Mesh.ARRAY_TEX_UV] != null:
					var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					var flat := PackedFloat32Array()
					flat.resize(uvs.size() * 2)
					for i in range(uvs.size()):
						flat[i * 2] = uvs[i].x
						flat[i * 2 + 1] = uvs[i].y
					result = _processor.process_uvs(flat, max_pts)
		break

	if result.is_empty():
		return null

	var out: GNChannelData = _prepare_output(60.0)
	for ch_name in result:
		out.channels[ch_name] = result[ch_name]
	out.length = max_pts
	return out
