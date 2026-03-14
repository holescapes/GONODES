class_name AttributeSOPNative
extends GNSopBase
## Native-accelerated attribute creation — delegates to GNNativeAttributeSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "attribute"
	time_dependent = true
	node_description = "Create/modify per-vertex point attributes — native C++ accelerated."
	if ClassDB.class_exists("GNNativeAttributeSop"):
		_processor = ClassDB.instantiate("GNNativeAttributeSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Geometry with attributes")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("name", "pscale", "Attribute Name", ""))
	add_parameter(GNParameter.create_enum("source",
		PackedStringArray(["Constant", "Expression", "Position X", "Position Y",
			"Position Z", "Normal Y", "UV U", "Random"]), 0, "", ""))
	add_parameter(GNParameter.create_float("value", 1.0, null, null, 0.01, "Constant Value", ""))
	add_parameter(GNParameter.create_string("expression", "sin(float(i) / float(n) * 6.28)", "Expression", ""))
	add_parameter(GNParameter.create_int("seed", 42, 0, 99999, "Seed", ""))
	add_parameter(GNParameter.create_float("rand_min", 0.0, null, null, 0.01, "Random Min", ""))
	add_parameter(GNParameter.create_float("rand_max", 1.0, null, null, 0.01, "Random Max", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()
	if in_geo.mesh:
		geo.set_mesh(in_geo.mesh.duplicate() as ArrayMesh)
	for key in in_geo.point_attribs:
		geo.point_attribs[key] = in_geo.point_attribs[key].duplicate()

	var attr_name: String = get_param_value("name")
	var source: int = get_param_value("source")

	# Get verts/normals/uvs from first surface
	if geo.mesh and geo.mesh.get_surface_count() > 0:
		var arrays: Array = geo.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] else PackedVector2Array()

		if _processor and not verts.is_empty():
			var values: PackedFloat32Array = _processor.process(verts, normals, uvs,
				source, get_param_value("value"), get_param_value("expression"),
				elapsed_time, get_param_value("seed"),
				get_param_value("rand_min"), get_param_value("rand_max"))
			geo.point_attribs[attr_name] = values

	return geo
