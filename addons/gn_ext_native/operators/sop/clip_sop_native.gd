class_name ClipSOPNative
extends GNSopBase
## Native-accelerated clip — delegates to GNNativeClipSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "clip_native"
	node_description = "Clip geometry against a plane — native C++ accelerated."
	if ClassDB.class_exists("GNNativeClipSop"):
		_processor = ClassDB.instantiate("GNNativeClipSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Clipped geometry", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("plane",
		PackedStringArray(["X", "Y", "Z"]), 1, "", "Clip plane normal axis"))
	add_parameter(GNParameter.create_float("origin", 0.0, null, null, 0.01, "Origin", ""))
	add_parameter(GNParameter.create_bool("keep_above", true, "", "Keep above the plane"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	var axis: int = get_param_value("plane")
	var origin_val: float = get_param_value("origin")
	var keep_above: bool = get_param_value("keep_above")

	var normal: Vector3
	match axis:
		0: normal = Vector3.RIGHT
		1: normal = Vector3.UP
		_: normal = Vector3.BACK
	if not keep_above:
		normal = -normal
		origin_val = -origin_val

	var new_mesh := ArrayMesh.new()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		if prim != Mesh.PRIMITIVE_TRIANGLES or arrays[Mesh.ARRAY_VERTEX] == null:
			new_mesh.add_surface_from_arrays(prim, arrays)
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		if indices.is_empty():
			indices.resize(verts.size())
			for i in range(verts.size()):
				indices[i] = i

		if _processor:
			var result: Dictionary = _processor.process(verts, uvs, indices, normal, origin_val)
			var out_v: PackedVector3Array = result.get("positions", PackedVector3Array())
			if out_v.is_empty():
				continue
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var out_u: PackedVector2Array = result.get("uvs", PackedVector2Array())
			for i in range(out_v.size()):
				if i < out_u.size():
					st.set_uv(out_u[i])
				st.add_vertex(out_v[i])
			st.generate_normals()
			new_mesh = st.commit(new_mesh)
		else:
			new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	return geo
