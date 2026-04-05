class_name TransformSOPNative
extends GNSopBase
## Native-accelerated transform — delegates to GNNativeTransformSop (C++).

var _processor: RefCounted = null


func _init() -> void:
	node_type = "transform"
	node_description = "Translate, rotate, and scale geometry — native C++ accelerated."
	if ClassDB.class_exists("GNNativeTransformSop"):
		_processor = ClassDB.instantiate("GNNativeTransformSop")


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Transformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", ""))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", ""))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", ""))
	add_parameter(GNParameter.create_float("rx", 0.0, null, null, 0.1, "Rotate X", ""))
	add_parameter(GNParameter.create_float("ry", 0.0, null, null, 0.1, "Rotate Y", ""))
	add_parameter(GNParameter.create_float("rz", 0.0, null, null, 0.1, "Rotate Z", ""))
	add_parameter(GNParameter.create_float("sx", 1.0, null, null, 0.01, "Scale X", ""))
	add_parameter(GNParameter.create_float("sy", 1.0, null, null, 0.01, "Scale Y", ""))
	add_parameter(GNParameter.create_float("sz", 1.0, null, null, 0.01, "Scale Z", ""))
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["SRT", "STR", "RST", "RTS", "TSR", "TRS"]), 0, "Transform Order", ""))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	var geo := _prepare_geo()

	var t_translate := Transform3D.IDENTITY.translated(Vector3(
		get_param_value("tx"), get_param_value("ty"), get_param_value("tz")))
	var t_rotate := Transform3D(Basis.from_euler(Vector3(
		deg_to_rad(get_param_value("rx")), deg_to_rad(get_param_value("ry")),
		deg_to_rad(get_param_value("rz")))), Vector3.ZERO)
	var t_scale := Transform3D.IDENTITY.scaled(Vector3(
		get_param_value("sx"), get_param_value("sy"), get_param_value("sz")))

	var xform: Transform3D
	match get_param_value("order"):
		0: xform = t_translate * t_rotate * t_scale
		1: xform = t_translate * t_scale * t_rotate
		2: xform = t_rotate * t_scale * t_translate
		3: xform = t_scale * t_rotate * t_translate
		4: xform = t_scale * t_translate * t_rotate
		5: xform = t_rotate * t_translate * t_scale
		_: xform = t_translate * t_rotate * t_scale

	var new_mesh := ArrayMesh.new()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] else PackedVector3Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] else PackedVector3Array()

		if _processor and not verts.is_empty():
			var result: Dictionary = _processor.process(verts, normals, xform)
			arrays[Mesh.ARRAY_VERTEX] = result.get("positions", verts)
			if result.has("normals"):
				arrays[Mesh.ARRAY_NORMAL] = result["normals"]
		new_mesh.add_surface_from_arrays(prim, arrays)

	geo.set_mesh(new_mesh)
	geo.transform = xform
	return geo
