class_name PrimitiveSOP
extends GNSopBase
## Reads and exposes per-primitive (per-face) attributes as point attribs.
## Computes face normals, face areas, face centroids, and optional face colors.
## Also allows setting a constant color per primitive index.

func _init() -> void:
	node_type = "primitive"
	node_description = "Compute per-primitive attributes (normals, area, centroid)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with per-primitive attribs")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("face_normals", true, "Face Normals",
		"Store face-normal as point attrib (fn_x, fn_y, fn_z)"))
	add_parameter(GNParameter.create_bool("face_area", false, "Face Area",
		"Store face area as point attrib (face_area)"))
	add_parameter(GNParameter.create_bool("face_centroid", false, "Face Centroid",
		"Store face centroid as point attrib (fc_x, fc_y, fc_z)"))
	add_parameter(GNParameter.create_bool("face_id", true, "Face ID",
		"Store primitive index as point attrib (prim_id)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = _get_input_sop(inputs, 0)
	if in_geo == null or not in_geo.has_geometry():
		return _prepare_geo()

	var geo: GNGeoData = in_geo.duplicate_data() as GNGeoData

	var do_normals: bool = get_param_value("face_normals")
	var do_area: bool = get_param_value("face_area")
	var do_centroid: bool = get_param_value("face_centroid")
	var do_id: bool = get_param_value("face_id")

	var total_verts: int = geo.vertex_count
	var fn_x := PackedFloat32Array(); fn_x.resize(total_verts); fn_x.fill(0.0)
	var fn_y := PackedFloat32Array(); fn_y.resize(total_verts); fn_y.fill(0.0)
	var fn_z := PackedFloat32Array(); fn_z.resize(total_verts); fn_z.fill(0.0)
	var area_arr := PackedFloat32Array(); area_arr.resize(total_verts); area_arr.fill(0.0)
	var fc_x := PackedFloat32Array(); fc_x.resize(total_verts); fc_x.fill(0.0)
	var fc_y := PackedFloat32Array(); fc_y.resize(total_verts); fc_y.fill(0.0)
	var fc_z := PackedFloat32Array(); fc_z.resize(total_verts); fc_z.fill(0.0)
	var id_arr := PackedFloat32Array(); id_arr.resize(total_verts); id_arr.fill(0.0)

	var vert_offset: int = 0
	var prim_counter: int = 0

	for s in range(geo.mesh.get_surface_count()):
		var arrays: Array = geo.mesh.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

		if indices.is_empty():
			for i in range(0, verts.size(), 3):
				var a: Vector3 = verts[i]
				var b: Vector3 = verts[i + 1]
				var c: Vector3 = verts[i + 2]
				var fn: Vector3 = (b - a).cross(c - a)
				var face_area: float = fn.length() * 0.5
				fn = fn.normalized()
				var centroid: Vector3 = (a + b + c) / 3.0

				for j in range(3):
					var gi: int = vert_offset + i + j
					if gi >= total_verts:
						break
					if do_normals:
						fn_x[gi] = fn.x; fn_y[gi] = fn.y; fn_z[gi] = fn.z
					if do_area:
						area_arr[gi] = face_area
					if do_centroid:
						fc_x[gi] = centroid.x; fc_y[gi] = centroid.y; fc_z[gi] = centroid.z
					if do_id:
						id_arr[gi] = float(prim_counter)
				prim_counter += 1
		else:
			for i in range(0, indices.size(), 3):
				var a: Vector3 = verts[indices[i]]
				var b: Vector3 = verts[indices[i + 1]]
				var c: Vector3 = verts[indices[i + 2]]
				var fn: Vector3 = (b - a).cross(c - a)
				var face_area: float = fn.length() * 0.5
				fn = fn.normalized()
				var centroid: Vector3 = (a + b + c) / 3.0

				for j in range(3):
					var gi: int = vert_offset + indices[i + j]
					if gi >= total_verts:
						break
					if do_normals:
						fn_x[gi] = fn.x; fn_y[gi] = fn.y; fn_z[gi] = fn.z
					if do_area:
						area_arr[gi] = face_area
					if do_centroid:
						fc_x[gi] = centroid.x; fc_y[gi] = centroid.y; fc_z[gi] = centroid.z
					if do_id:
						id_arr[gi] = float(prim_counter)
				prim_counter += 1

		vert_offset += verts.size()

	if do_normals:
		geo.set_point_attrib("fn_x", fn_x)
		geo.set_point_attrib("fn_y", fn_y)
		geo.set_point_attrib("fn_z", fn_z)
	if do_area:
		geo.set_point_attrib("face_area", area_arr)
	if do_centroid:
		geo.set_point_attrib("fc_x", fc_x)
		geo.set_point_attrib("fc_y", fc_y)
		geo.set_point_attrib("fc_z", fc_z)
	if do_id:
		geo.set_point_attrib("prim_id", id_arr)

	return geo
