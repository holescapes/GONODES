class_name TextureSOPNative
extends GNSopBase
## Native-accelerated texture sampling — delegates to GNNativeTextureSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "texture_native"
	if ClassDB.class_exists("GNNativeTextureSop"):
		_processor = ClassDB.instantiate("GNNativeTextureSop")


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, false, "Input geometry with UVs")
	add_input("tex", GNFamily.Type.TOP, true, "Texture input")
	add_output("out", GNFamily.Type.SOP, "Textured geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Vertex Color", "Displace"]), 0,
		"Mode", "Texture application mode"))
	add_parameter(GNParameter.create_float("scale", 1.0, -100.0, 100.0, 0.01,
		"Scale", "Displacement scale (displace mode only)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var mode: int = get_param_value("mode")
	var scale: float = get_param_value("scale")
	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()

		if verts == null or uvs.is_empty() or _processor == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		# Get texture image
		var tex_data = inputs[1] if inputs.size() > 1 else null
		var image: Image = null
		if tex_data != null and tex_data.has_method("get_texture"):
			var tex: Texture2D = tex_data.get_texture()
			if tex != null:
				image = tex.get_image()

		if image == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if mode == 0:
			var colors: PackedColorArray = _processor.sample_colors(uvs, image)
			arrays[Mesh.ARRAY_COLOR] = colors
		elif mode == 1 and normals.size() == verts.size():
			arrays[Mesh.ARRAY_VERTEX] = _processor.displace(verts, normals, uvs, image, scale)

		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
