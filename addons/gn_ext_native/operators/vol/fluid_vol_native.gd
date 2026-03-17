class_name FluidVOLNative
extends GNVolBase
## Native-accelerated Navier-Stokes fluid simulation — delegates to GNNativeFluidVol (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "fluid"
	time_dependent = true
	node_description = "Navier-Stokes fluid solver with density & velocity — native C++ accelerated."
	if ClassDB.class_exists("GNNativeFluidVol"):
		_processor = ClassDB.instantiate("GNNativeFluidVol")


func _init_ports() -> void:
	add_input("density_in", GNFamily.Type.VOL, false, "External density source (optional)")
	add_input("vel_in", GNFamily.Type.VOL, false, "External velocity field (optional)")
	add_output("density_out", GNFamily.Type.VOL, "Density volume")
	add_output("velocity_out", GNFamily.Type.VOL, "Velocity volume (4-channel)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("res_x", 64, 8, 256, "Res X", "Grid width"))
	add_parameter(GNParameter.create_int("res_y", 64, 8, 256, "Res Y", "Grid height"))
	add_parameter(GNParameter.create_int("res_z", 64, 8, 256, "Res Z", "Grid depth"))
	add_parameter(GNParameter.create_float("dissipation", 0.98, 0.8, 1.0, 0.01,
		"Dissipation", "Density decay factor per step"))
	add_parameter(GNParameter.create_int("pressure_iters", 20, 5, 50,
		"Pressure Iterations", "Jacobi pressure solver iterations"))
	add_parameter(GNParameter.create_float("density_add", 1.0, 0.0, 10.0, 0.1,
		"Density Add", "Density injection amount"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset",
		"Clear simulation state"))


func _cook(inputs: Array[GNData]) -> GNData:
	if not _processor:
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var rx: int = get_param_value("res_x")
	var ry: int = get_param_value("res_y")
	var rz: int = get_param_value("res_z")
	var total: int = rx * ry * rz

	# Build density source from input or empty
	var density_source := PackedFloat32Array()
	var den_vol: GNVolumeData = _get_input_vol(inputs, 0)
	if den_vol != null and den_vol.has_volume():
		var raw: PackedByteArray = den_vol.read_full()
		density_source.resize(total)
		for i in range(mini(total, raw.size() / 4)):
			density_source[i] = raw.decode_float(i * 4)
	else:
		density_source.resize(total)
		density_source.fill(0.0)

	var do_reset: bool = get_param_value("reset")
	if do_reset:
		set_param_value("reset", false)

	var result: Dictionary = _processor.step(density_source, rx, ry, rz,
		current_delta, get_param_value("dissipation"),
		get_param_value("pressure_iters"), get_param_value("density_add"),
		do_reset)

	var den_field: PackedFloat32Array = result.get("density", PackedFloat32Array())
	if den_field.is_empty():
		return null

	# Upload density output
	var res := Vector3i(rx, ry, rz)
	var out_vol := _create_volume(res, RenderingDevice.DATA_FORMAT_R32_SFLOAT, "density")
	var bytes := PackedByteArray()
	bytes.resize(den_field.size() * 4)
	for i in range(den_field.size()):
		bytes.encode_float(i * 4, den_field[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
