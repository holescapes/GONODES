class_name SOPtoVOLNative
extends GNVolBase
## Native-accelerated SOP→VOL point splatting — delegates to GNNativeSopToVol (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "soptovol_native"
	node_description = "Rasterize SOP points into a density volume — native C++ accelerated."
	if ClassDB.class_exists("GNNativeSopToVol"):
		_processor = ClassDB.instantiate("GNNativeSopToVol")


func _init_ports() -> void:
	add_input("geo", GNFamily.Type.SOP, true, "Input geometry")
	add_output("out", GNFamily.Type.VOL, "Density volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 256, "Res X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 256, "Res Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 256, "Res Z", "Grid depth"))
	add_parameter(GNParameter.create_float("radius", 0.05, 0.001, 1.0, 0.001,
		"Radius", "Splat radius per point"))
	add_parameter(GNParameter.create_float("strength", 1.0, 0.01, 10.0, 0.01,
		"Strength", "Density contribution per point"))
	add_parameter(GNParameter.create_float("padding", 0.1, 0.0, 2.0, 0.01,
		"Padding", "AABB padding factor"))


func _cook(inputs: Array[GNData]) -> GNData:
	var in_geo: GNGeoData = inputs[0] as GNGeoData if inputs.size() > 0 and inputs[0] is GNGeoData else null
	if in_geo == null or not in_geo.has_geometry() or not _processor:
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var positions := PackedVector3Array()
	for s in range(in_geo.get_surface_count()):
		var arrays: Array = in_geo.get_surface_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] != null:
			positions = arrays[Mesh.ARRAY_VERTEX]
			break
	if positions.is_empty():
		return null

	var rx: int = get_param_value("res_x")
	var ry: int = get_param_value("res_y")
	var rz: int = get_param_value("res_z")

	var result: Dictionary = _processor.process(positions, rx, ry, rz,
		get_param_value("radius"), get_param_value("strength"),
		get_param_value("padding"))

	var field: PackedFloat32Array = result.get("field", PackedFloat32Array())
	if field.is_empty():
		return null

	var res := Vector3i(rx, ry, rz)
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
	var bytes := PackedByteArray()
	bytes.resize(field.size() * 4)
	for i in range(field.size()):
		bytes.encode_float(i * 4, field[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
