class_name NormalSOPNative
extends GNSopBase
## Native-accelerated normal recomputation — delegates to GNNativeNormalSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "normal_native"
	node_description = "Recompute, flip, or facet vertex normals — native C++ accelerated."
	if ClassDB.class_exists("GNNativeNormalSop"):
		_processor = ClassDB.instantiate("GNNativeNormalSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with new normals")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Recompute (Smooth)", "Flip", "Flat (Faceted)"]), 0, "", ""))
	add_parameter(GNParameter.create_bool("generate_tangents", true, "", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var mode: int = get_param_value("mode")
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()

		if verts.is_empty() or not _processor:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if indices.is_empty():
			indices.resize(verts.size())
			for i in range(verts.size()):
				indices[i] = i

		var result: Dictionary = _processor.process(verts, normals, uvs, indices, mode)
		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts)
		arrays[Mesh.ARRAY_NORMAL] = result.get("normals", normals)
		if result.has("uvs") and not result["uvs"].is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		# Flat mode unshares verts, so clear indices
		if mode == 2:
			arrays[Mesh.ARRAY_INDEX] = null
			arrays[Mesh.ARRAY_TANGENT] = null
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
