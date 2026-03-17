class_name BlendSOP
extends GNSopBase
## Morphs between two input geometries by linearly interpolating vertex
## positions, normals, and UVs. Both meshes must have the same vertex count
## per surface for blending to work; mismatched surfaces are passed through
## from input 0.

func _init() -> void:
	node_type = "blend"
	node_description = "Morph/blend between two geometries."


func _init_ports() -> void:
	add_input("geo_a", GNFamily.Type.SOP, false, "Base geometry (blend = 0)", "Geometry A")
	add_input("geo_b", GNFamily.Type.SOP, false, "Target geometry (blend = 1)", "Geometry B")
	add_output("out", GNFamily.Type.SOP, "Blended geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blend", 0.5, 0.0, 1.0, 0.01,
		"Blend", "Interpolation factor 0=A  1=B"))
	add_parameter(GNParameter.create_bool("blend_normals", true, "Blend Normals",
		"Also interpolate normals"))
	add_parameter(GNParameter.create_bool("blend_uvs", false, "Blend UVs",
		"Also interpolate UVs"))


func _cook(inputs: Array[GNData]) -> GNData:
	var geo_a: GNGeoData = _get_input_sop(inputs, 0)
	var geo_b: GNGeoData = _get_input_sop(inputs, 1)

	if geo_a == null or not geo_a.has_geometry():
		return _prepare_geo()
	if geo_b == null or not geo_b.has_geometry():
		return geo_a

	var blend_val: float = get_param_value("blend")
	var do_normals: bool = get_param_value("blend_normals")
	var do_uvs: bool = get_param_value("blend_uvs")

	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	var surf_count_a: int = geo_a.mesh.get_surface_count()
	var surf_count_b: int = geo_b.mesh.get_surface_count()
	var surf_count: int = mini(surf_count_a, surf_count_b)

	for s in range(surf_count):
		var arr_a: Array = geo_a.mesh.surface_get_arrays(s)
		var arr_b: Array = geo_b.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_a.mesh.surface_get_primitive_type(s)

		if arr_a[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts_a: PackedVector3Array = arr_a[Mesh.ARRAY_VERTEX]
		var verts_b: PackedVector3Array = arr_b[Mesh.ARRAY_VERTEX] if arr_b[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()

		if verts_a.size() != verts_b.size():
			# Vertex count mismatch — pass through A
			new_mesh.add_surface_from_arrays(prim, arr_a)
			continue

		var out_arrays: Array = arr_a.duplicate(true)

		# Blend positions
		var blended_verts := PackedVector3Array()
		blended_verts.resize(verts_a.size())
		for i in range(verts_a.size()):
			blended_verts[i] = verts_a[i].lerp(verts_b[i], blend_val)
		out_arrays[Mesh.ARRAY_VERTEX] = blended_verts

		# Blend normals
		if do_normals and arr_a[Mesh.ARRAY_NORMAL] != null and arr_b[Mesh.ARRAY_NORMAL] != null:
			var norms_a: PackedVector3Array = arr_a[Mesh.ARRAY_NORMAL]
			var norms_b: PackedVector3Array = arr_b[Mesh.ARRAY_NORMAL]
			if norms_a.size() == norms_b.size():
				var blended_norms := PackedVector3Array()
				blended_norms.resize(norms_a.size())
				for i in range(norms_a.size()):
					blended_norms[i] = norms_a[i].lerp(norms_b[i], blend_val).normalized()
				out_arrays[Mesh.ARRAY_NORMAL] = blended_norms

		# Blend UVs
		if do_uvs and arr_a[Mesh.ARRAY_TEX_UV] != null and arr_b[Mesh.ARRAY_TEX_UV] != null:
			var uvs_a: PackedVector2Array = arr_a[Mesh.ARRAY_TEX_UV]
			var uvs_b: PackedVector2Array = arr_b[Mesh.ARRAY_TEX_UV]
			if uvs_a.size() == uvs_b.size():
				var blended_uvs := PackedVector2Array()
				blended_uvs.resize(uvs_a.size())
				for i in range(uvs_a.size()):
					blended_uvs[i] = uvs_a[i].lerp(uvs_b[i], blend_val)
				out_arrays[Mesh.ARRAY_TEX_UV] = blended_uvs

		new_mesh.add_surface_from_arrays(prim, out_arrays)

	# Any extra surfaces from A beyond surf_count get passed through
	for s in range(surf_count, surf_count_a):
		var arr_a: Array = geo_a.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_a.mesh.surface_get_primitive_type(s)
		new_mesh.add_surface_from_arrays(prim, arr_a)

	geo.set_mesh(new_mesh)
	return geo
