class_name DivideSOPNative
extends GNSopBase
## Native-accelerated divide/clean — delegates to GNNativeDivideSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "divide_native"
	node_description = "Triangulate or clean mesh topology — native C++ accelerated."
	if ClassDB.class_exists("GNNativeDivideSop"):
		_processor = ClassDB.instantiate("GNNativeDivideSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Cleaned geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Triangulate", "Convex Decompose"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_bool("remove_degenerate", true, "Remove Degenerate", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var remove_degen: bool = get_param_value("remove_degenerate")
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

		if remove_degen and _processor and not indices.is_empty():
			arrays[Mesh.ARRAY_INDEX] = _processor.remove_degenerate(verts, indices)
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
