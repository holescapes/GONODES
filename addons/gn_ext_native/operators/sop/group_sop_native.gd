class_name GroupSOPNative
extends GNSopBase
## Native-accelerated vertex grouping — delegates to GNNativeGroupSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "group"
	if ClassDB.class_exists("GNNativeGroupSop"):
		_processor = ClassDB.instantiate("GNNativeGroupSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with group attribute")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["BBox", "Normal Direction", "All"]), 0,
		"Mode", "Grouping method"))
	add_parameter(GNParameter.create_float("min_x", -1.0, null, null, 0.01, "Min X", ""))
	add_parameter(GNParameter.create_float("min_y", -1.0, null, null, 0.01, "Min Y", ""))
	add_parameter(GNParameter.create_float("min_z", -1.0, null, null, 0.01, "Min Z", ""))
	add_parameter(GNParameter.create_float("max_x", 1.0, null, null, 0.01, "Max X", ""))
	add_parameter(GNParameter.create_float("max_y", 1.0, null, null, 0.01, "Max Y", ""))
	add_parameter(GNParameter.create_float("max_z", 1.0, null, null, 0.01, "Max Z", ""))
	add_parameter(GNParameter.create_float("dir_x", 0.0, -1.0, 1.0, 0.01, "Direction X", ""))
	add_parameter(GNParameter.create_float("dir_y", 1.0, -1.0, 1.0, 0.01, "Direction Y", ""))
	add_parameter(GNParameter.create_float("dir_z", 0.0, -1.0, 1.0, 0.01, "Direction Z", ""))
	add_parameter(GNParameter.create_float("angle", 45.0, 0.0, 180.0, 0.1, "Angle", "Normal cone angle"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo := _require_input_geo(inputs)
	if in_geo == null:
		return null

	var mode: int = get_param_value("mode")
	var geo := _prepare_geo()
	var new_mesh := ArrayMesh.new()

	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		new_mesh.add_surface_from_arrays(prim, arrays)

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or _processor == null:
			continue

		var group_vals: PackedFloat32Array
		match mode:
			0:
				var mn := Vector3(get_param_value("min_x"), get_param_value("min_y"), get_param_value("min_z"))
				var mx := Vector3(get_param_value("max_x"), get_param_value("max_y"), get_param_value("max_z"))
				group_vals = _processor.group_by_bbox(verts, mn, mx)
			1:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				if normals.size() == verts.size():
					var dir := Vector3(get_param_value("dir_x"), get_param_value("dir_y"), get_param_value("dir_z")).normalized()
					group_vals = _processor.group_by_normal(normals, dir, get_param_value("angle"))
				else:
					group_vals = PackedFloat32Array()
					group_vals.resize(verts.size())
					group_vals.fill(1.0)
			_:
				group_vals = PackedFloat32Array()
				group_vals.resize(verts.size())
				group_vals.fill(1.0)

		geo.point_attribs["group"] = group_vals

	geo.set_mesh(new_mesh)
	return geo
