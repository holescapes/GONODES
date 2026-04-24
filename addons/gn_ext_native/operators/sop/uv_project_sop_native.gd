class_name UVProjectSOPNative
extends GNSopBase
## Native-accelerated UV projection — delegates to GNNativeUvProjectSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "uvproject_native"
	node_description = "Project UV coordinates onto geometry — native C++ accelerated."
	if ClassDB.class_exists("GNNativeUvProjectSop"):
		_processor = ClassDB.instantiate("GNNativeUvProjectSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with projected UVs")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Planar", "Cylindrical", "Spherical"]), 0, "Mode", ""))
	add_parameter(GNParameter.create_enum("axis",
		PackedStringArray(["X", "Y", "Z"]), 1, "Axis", ""))
	add_parameter(GNParameter.create_float("scale_u", 1.0, 0.001, 100.0, 0.01, "Scale U", ""))
	add_parameter(GNParameter.create_float("scale_v", 1.0, 0.001, 100.0, 0.01, "Scale V", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		if verts.is_empty() or not _processor:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var new_uvs: PackedVector2Array = _processor.process(verts,
			get_param_value("mode"), get_param_value("axis"),
			get_param_value("scale_u"), get_param_value("scale_v"))
		arrays[Mesh.ARRAY_TEX_UV] = new_uvs
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
