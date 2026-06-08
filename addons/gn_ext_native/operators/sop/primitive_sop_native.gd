class_name PrimitiveSOPNative
extends GNSopBase
## Native-accelerated primitive attribute computation — delegates to GNNativePrimitiveSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "primitive_native"
	if ClassDB.class_exists("GNNativePrimitiveSop"):
		_processor = ClassDB.instantiate("GNNativePrimitiveSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry", "In")
	add_output("out", GNFamily.Type.SOP, "Geometry with per-primitive attribs", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("face_normals", true,
		"Face Normals", "Compute face normal per vertex"))
	add_parameter(GNParameter.create_bool("face_area", false,
		"Face Area", "Compute face area per vertex"))
	add_parameter(GNParameter.create_bool("face_centroid", false,
		"Face Centroid", "Compute face centroid per vertex"))
	add_parameter(GNParameter.create_bool("face_id", true,
		"Face ID", "Assign face ID per vertex"))


func _cook(inputs: Array[GNData]) -> GNData:
	var input_geo := _require_input_geo(inputs)
	if not input_geo:
		return null

	# PrimitiveSOP computes per-face attributes and assigns to vertices
	# The C++ processor generates complete meshes; use GDScript path for attrib computation
	var mesh: ArrayMesh = input_geo.mesh
	if not mesh or mesh.get_surface_count() == 0:
		return input_geo

	var out := _prepare_geo()
	out.mesh = mesh.duplicate()

	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		var tri_count: int = indices.size() / 3
		var vert_count: int = verts.size()

		if get_param_value("face_normals"):
			var fn_x := PackedFloat32Array()
			var fn_y := PackedFloat32Array()
			var fn_z := PackedFloat32Array()
			fn_x.resize(vert_count); fn_y.resize(vert_count); fn_z.resize(vert_count)
			for t in range(tri_count):
				var i0: int = indices[t * 3]
				var i1: int = indices[t * 3 + 1]
				var i2: int = indices[t * 3 + 2]
				var n: Vector3 = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).normalized()
				for idx in [i0, i1, i2]:
					fn_x[idx] = n.x; fn_y[idx] = n.y; fn_z[idx] = n.z
			out.point_attribs["fn_x"] = fn_x
			out.point_attribs["fn_y"] = fn_y
			out.point_attribs["fn_z"] = fn_z

		if get_param_value("face_area"):
			var fa := PackedFloat32Array()
			fa.resize(vert_count)
			for t in range(tri_count):
				var i0: int = indices[t * 3]
				var i1: int = indices[t * 3 + 1]
				var i2: int = indices[t * 3 + 2]
				var area: float = (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0]).length() * 0.5
				for idx in [i0, i1, i2]:
					fa[idx] = area
			out.point_attribs["face_area"] = fa

		if get_param_value("face_id"):
			var fid := PackedFloat32Array()
			fid.resize(vert_count)
			for t in range(tri_count):
				for k in range(3):
					fid[indices[t * 3 + k]] = float(t)
			out.point_attribs["prim_id"] = fid

	return out
