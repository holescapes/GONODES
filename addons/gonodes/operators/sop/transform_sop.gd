class_name TransformSOP
extends GNSopBase
## Applies translate, rotate, and scale transformations to input geometry.
## Uses Godot's Transform3D for robust 3D transform operations.


func _init() -> void:
	node_type = "transform"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Transformed geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tx", 0.0, null, null, 0.01, "Translate X", "Translation along X"))
	add_parameter(GNParameter.create_float("ty", 0.0, null, null, 0.01, "Translate Y", "Translation along Y"))
	add_parameter(GNParameter.create_float("tz", 0.0, null, null, 0.01, "Translate Z", "Translation along Z"))
	add_parameter(GNParameter.create_float("rx", 0.0, -360.0, 360.0, 0.1, "Rotate X", "Rotation around X (degrees)"))
	add_parameter(GNParameter.create_float("ry", 0.0, -360.0, 360.0, 0.1, "Rotate Y", "Rotation around Y (degrees)"))
	add_parameter(GNParameter.create_float("rz", 0.0, -360.0, 360.0, 0.1, "Rotate Z", "Rotation around Z (degrees)"))
	add_parameter(GNParameter.create_float("sx", 1.0, 0.001, 100.0, 0.01, "Scale X", "Scale along X"))
	add_parameter(GNParameter.create_float("sy", 1.0, 0.001, 100.0, 0.01, "Scale Y", "Scale along Y"))
	add_parameter(GNParameter.create_float("sz", 1.0, 0.001, 100.0, 0.01, "Scale Z", "Scale along Z"))
	add_parameter(GNParameter.create_enum("order",
		PackedStringArray(["SRT", "STR", "RST", "RTS", "TSR", "TRS"]), 0, "Transform Order", "Order of transform operations"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry():
		return null

	if _cached_geo == null:
		_cached_geo = GNGeoData.new()
	_cached_geo.clear()

	var tx: float = get_param_value("tx")
	var ty: float = get_param_value("ty")
	var tz: float = get_param_value("tz")
	var rx: float = deg_to_rad(get_param_value("rx"))
	var ry: float = deg_to_rad(get_param_value("ry"))
	var rz: float = deg_to_rad(get_param_value("rz"))
	var sx: float = get_param_value("sx")
	var sy: float = get_param_value("sy")
	var sz: float = get_param_value("sz")

	# Build transform components
	var t_translate := Transform3D.IDENTITY.translated(Vector3(tx, ty, tz))
	var t_rotate := Transform3D(Basis.from_euler(Vector3(rx, ry, rz)), Vector3.ZERO)
	var t_scale := Transform3D.IDENTITY.scaled(Vector3(sx, sy, sz))

	# Compose based on order
	var xform: Transform3D
	match get_param_value("order"):
		0: xform = t_translate * t_rotate * t_scale  # SRT
		1: xform = t_translate * t_scale * t_rotate  # STR
		2: xform = t_rotate * t_scale * t_translate  # RST (note: reversed application)
		3: xform = t_scale * t_rotate * t_translate  # RTS
		4: xform = t_scale * t_translate * t_rotate  # TSR
		5: xform = t_rotate * t_translate * t_scale  # TRS
		_: xform = t_translate * t_rotate * t_scale

	# Apply transform to all surfaces
	var new_mesh := ArrayMesh.new()
	for s in range(in_geo.mesh.get_surface_count()):
		var arrays: Array = in_geo.mesh.surface_get_arrays(s)
		var prim: Mesh.PrimitiveType = in_geo.mesh.surface_get_primitive_type(s)

		# Transform positions
		if arrays[Mesh.ARRAY_VERTEX] != null:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var new_verts := PackedVector3Array()
			new_verts.resize(verts.size())
			for i in range(verts.size()):
				new_verts[i] = xform * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = new_verts

		# Transform normals (use basis only, no translation)
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var new_normals := PackedVector3Array()
			new_normals.resize(normals.size())
			var normal_basis: Basis = xform.basis.inverse().transposed()
			for i in range(normals.size()):
				new_normals[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = new_normals

		new_mesh.add_surface_from_arrays(prim, arrays)

	_cached_geo.set_mesh(new_mesh)
	_cached_geo.transform = xform
	return _cached_geo
