class_name TextureSOP
extends GNSopBase
## Apply a TOP texture to SOP geometry as a vertex color or displacement.
##
## Samples the input texture at each vertex's UV coordinate and stores
## the result as vertex colors or displaces vertices along normals.
##
## TouchDesigner equivalent: Texture SOP.


func _init() -> void:
	node_type = "texture"


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, false, "Input geometry with UVs", "Geometry")
	add_input("tex", GNFamily.Type.TOP, false, "Texture to sample", "Texture")
	add_output("out", GNFamily.Type.SOP, "Textured geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode", ["Vertex Color", "Displacement"],
		0, "Mode", "How to apply the texture"))
	add_parameter(GNParameter.create_float("displacement_scale", 0.1, 0.0, 10.0, 0.001,
		"Displacement Scale", "Displacement multiplier (Displacement mode only)"))
	add_parameter(GNParameter.create_int("uv_set", 0, 0, 1,
		"UV Set", "Which UV set to sample (0 or 1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return null

	var tex_data: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null
	if tex_data == null or tex_data.texture == null:
		return in_geo

	var mode: int = get_param_value("mode")
	var disp_scale: float = get_param_value("displacement_scale")
	var uv_set: int = get_param_value("uv_set")

	# Get Image from texture for CPU sampling
	var image: Image = tex_data.texture.get_image()
	if image == null:
		return in_geo

	var out_geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for surf_idx in range(in_geo.mesh.get_surface_count()):
		var arrays := in_geo.mesh.surface_get_arrays(surf_idx)
		var prim := in_geo.mesh.surface_get_primitive_type(surf_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array
		if uv_set == 0 and arrays[Mesh.ARRAY_TEX_UV] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV]
		elif uv_set == 1 and arrays[Mesh.ARRAY_TEX_UV2] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV2]
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		if verts.size() != uvs.size():
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var img_w := image.get_width()
		var img_h := image.get_height()

		if mode == 0:  # Vertex Color
			var colors := PackedColorArray()
			colors.resize(verts.size())
			for vi in range(verts.size()):
				var uv := uvs[vi]
				var px := clampi(int(uv.x * float(img_w - 1)), 0, img_w - 1)
				var py := clampi(int((1.0 - uv.y) * float(img_h - 1)), 0, img_h - 1)
				colors[vi] = image.get_pixel(px, py)
			arrays[Mesh.ARRAY_COLOR] = colors

		elif mode == 1:  # Displacement
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var displaced := verts.duplicate()
			for vi in range(verts.size()):
				var uv := uvs[vi]
				var px := clampi(int(uv.x * float(img_w - 1)), 0, img_w - 1)
				var py := clampi(int((1.0 - uv.y) * float(img_h - 1)), 0, img_h - 1)
				var col := image.get_pixel(px, py)
				var luma := col.r * 0.299 + col.g * 0.587 + col.b * 0.114
				var n := normals[vi] if vi < normals.size() else Vector3.UP
				displaced[vi] = verts[vi] + n * luma * disp_scale
			arrays[Mesh.ARRAY_VERTEX] = displaced

		new_mesh.add_surface_from_arrays(prim, arrays)

	out_geo.set_mesh(new_mesh)
	return out_geo
