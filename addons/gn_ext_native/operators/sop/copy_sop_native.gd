class_name CopySOPNative
extends GNSopBase
## Native-accelerated copy-to-points — delegates to GNNativeCopy (C++) when
## available, falls back to pure GDScript otherwise.

var _processor: RefCounted = null


func _init() -> void:
	node_type = "copy_native"
	node_description = "Copy geometry onto points (native C++ accelerated)."
	if ClassDB.class_exists("GNNativeCopy"):
		_processor = ClassDB.instantiate("GNNativeCopy")


func _init_ports() -> void:
	add_input("template", GNFamily.Type.SOP, false, "Template geometry to copy", "Template")
	add_input("points", GNFamily.Type.SOP, false, "Target points / mesh", "Points")
	add_output("out", GNFamily.Type.SOP, "Instanced copies", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("align_to_normal", true, "",
		"Rotate copies to align with target point normals"))
	add_parameter(GNParameter.create_float("scale", 1.0, 0.001, 100.0, 0.01,
		"Scale", "Uniform scale per copy"))
	add_parameter(GNParameter.create_bool("use_point_scale", false, "",
		"Use 'pscale' point attribute from target for per-point scale"))


func _cook(inputs: Array[GNData]) -> GNData:
	var template_geo: GNGeoData = _get_input_sop(inputs, 0)
	var points_geo: GNGeoData = _get_input_sop(inputs, 1)

	if template_geo == null or not template_geo.has_geometry():
		return null
	if points_geo == null or not points_geo.has_geometry():
		return null

	var align: bool = get_param_value("align_to_normal")
	var base_scale: float = get_param_value("scale")
	var use_pscale: bool = get_param_value("use_point_scale")

	# Extract template arrays (first surface)
	var tmpl_pos := PackedVector3Array()
	var tmpl_nrm := PackedVector3Array()
	var tmpl_uvs := PackedVector2Array()
	var tmpl_idx := PackedInt32Array()
	for s in range(template_geo.get_surface_count()):
		var arrays: Array = template_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			tmpl_pos = arrays[Mesh.ARRAY_VERTEX]
			if arrays[Mesh.ARRAY_NORMAL] != null:
				tmpl_nrm = arrays[Mesh.ARRAY_NORMAL]
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				tmpl_uvs = arrays[Mesh.ARRAY_TEX_UV]
			if arrays[Mesh.ARRAY_INDEX] != null:
				tmpl_idx = arrays[Mesh.ARRAY_INDEX]
			break

	# Extract target positions and normals
	var tgt_pos := PackedVector3Array()
	var tgt_nrm := PackedVector3Array()
	for s in range(points_geo.get_surface_count()):
		var arrays: Array = points_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			tgt_pos.append_array(arrays[Mesh.ARRAY_VERTEX])
			if arrays[Mesh.ARRAY_NORMAL] != null:
				tgt_nrm.append_array(arrays[Mesh.ARRAY_NORMAL])
			else:
				var pad := PackedVector3Array()
				pad.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
				pad.fill(Vector3.UP)
				tgt_nrm.append_array(pad)

	# Per-point scale
	var pscale := PackedFloat32Array()
	if use_pscale:
		pscale = points_geo.get_point_attrib("pscale")

	if tmpl_pos.is_empty() or tgt_pos.is_empty():
		return null

	if _processor != null:
		var result: Dictionary = _processor.process(tmpl_pos, tmpl_nrm, tmpl_uvs,
			tmpl_idx, tgt_pos, tgt_nrm, pscale, align, base_scale)
		var out_pos: PackedVector3Array = result.get("positions", PackedVector3Array())
		var out_nrm: PackedVector3Array = result.get("normals", PackedVector3Array())
		var out_uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())
		var out_idx: PackedInt32Array = result.get("indices", PackedInt32Array())

		if out_pos.is_empty():
			return null

		var out := _prepare_geo()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_pos
		if not out_nrm.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = out_nrm
		if not out_uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = out_uvs
		if not out_idx.is_empty():
			arrays[Mesh.ARRAY_INDEX] = out_idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.set_mesh(mesh)
		return out
	else:
		return null  # Fallback handled by core CopySOP
