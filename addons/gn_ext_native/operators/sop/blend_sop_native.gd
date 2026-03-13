class_name BlendSOPNative
extends GNSopBase
## Native-accelerated geometry morph — delegates to GNNativeBlendSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "blend"
	node_description = "Morph/blend between two geometries — native C++ accelerated."
	if ClassDB.class_exists("GNNativeBlendSop"):
		_processor = ClassDB.instantiate("GNNativeBlendSop")


func _init_ports() -> void:
	add_input("geo_a", GNFamily.Type.SOP, false, "Base geometry (blend = 0)")
	add_input("geo_b", GNFamily.Type.SOP, false, "Target geometry (blend = 1)")
	add_output("out", GNFamily.Type.SOP, "Blended geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("blend", 0.5, 0.0, 1.0, 0.01, "Blend", "0=A 1=B"))
	add_parameter(GNParameter.create_bool("blend_normals", true, "Blend Normals", ""))
	add_parameter(GNParameter.create_bool("blend_uvs", false, "Blend UVs", ""))


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

		var verts_a: PackedVector3Array = arr_a[Mesh.ARRAY_VERTEX] if arr_a[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
		var verts_b: PackedVector3Array = arr_b[Mesh.ARRAY_VERTEX] if arr_b[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()

		if verts_a.size() != verts_b.size() or verts_a.is_empty():
			new_mesh.add_surface_from_arrays(prim, arr_a)
			continue

		if _processor != null:
			var normals_a: PackedVector3Array = arr_a[Mesh.ARRAY_NORMAL] if arr_a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var normals_b: PackedVector3Array = arr_b[Mesh.ARRAY_NORMAL] if arr_b[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs_a: PackedVector2Array = arr_a[Mesh.ARRAY_TEX_UV] if arr_a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var uvs_b: PackedVector2Array = arr_b[Mesh.ARRAY_TEX_UV] if arr_b[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()

			var result: Dictionary = _processor.process(verts_a, verts_b,
				normals_a, normals_b, uvs_a, uvs_b, blend_val, do_normals, do_uvs)

			var out_arrays: Array = arr_a.duplicate(true)
			out_arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts_a)
			if do_normals and result.has("normals"):
				out_arrays[Mesh.ARRAY_NORMAL] = result["normals"]
			if do_uvs and result.has("uvs"):
				out_arrays[Mesh.ARRAY_TEX_UV] = result["uvs"]
			new_mesh.add_surface_from_arrays(prim, out_arrays)
		else:
			new_mesh.add_surface_from_arrays(prim, arr_a)

	for s in range(surf_count, surf_count_a):
		var arr_a: Array = geo_a.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = geo_a.mesh.surface_get_primitive_type(s)
		new_mesh.add_surface_from_arrays(prim, arr_a)

	geo.set_mesh(new_mesh)
	return geo
