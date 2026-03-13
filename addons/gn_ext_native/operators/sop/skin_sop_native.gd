class_name SkinSOPNative
extends GNSopBase
## Native-accelerated skin — delegates to GNNativeSkinSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "skin"
	node_description = "Skin cross-sections into a mesh surface — native C++ accelerated."
	_enable_dynamic_inputs(GNFamily.Type.SOP, "section", "Cross-section")
	if ClassDB.class_exists("GNNativeSkinSop"):
		_processor = ClassDB.instantiate("GNNativeSkinSop")


func _init_ports() -> void:
	add_input("section_0", GNFamily.Type.SOP, false, "Cross-section 0")
	add_output("out", GNFamily.Type.SOP, "Skinned mesh")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("close_u", true, "", "Close each ring"))
	add_parameter(GNParameter.create_bool("close_v", false, "", "Close along backbone"))
	add_parameter(GNParameter.create_bool("end_caps", false, "", "Cap ends"))
	add_parameter(GNParameter.create_bool("recompute_normals", true, "", "Recompute smooth normals"))


func _cook(inputs: Array[GNData]) -> GNData:
	var sections := Array()
	for i in range(inputs.size()):
		var geo: GNGeoData = inputs[i] as GNGeoData if i < inputs.size() and inputs[i] is GNGeoData else null
		if geo != null and geo.has_geometry():
			var pts := _extract_points(geo)
			if pts.size() > 0:
				sections.append(pts)

	if sections.size() < 2:
		return _prepare_geo()

	var close_u: bool = get_param_value("close_u")
	var close_v: bool = get_param_value("close_v")

	if _processor != null:
		var result: Dictionary = _processor.process(sections, close_u, close_v)

		var geo := _prepare_geo()
		var new_mesh := ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = result.get("positions", PackedVector3Array())
		if result.has("normals"):
			arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		if result.has("uvs"):
			arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
		if result.has("indices"):
			arrays[Mesh.ARRAY_INDEX] = result["indices"]
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		geo.set_mesh(new_mesh)
		return geo
	else:
		return _prepare_geo()


func _extract_points(geo: GNGeoData) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			pts.append_array(arrays[Mesh.ARRAY_VERTEX])
	return pts
