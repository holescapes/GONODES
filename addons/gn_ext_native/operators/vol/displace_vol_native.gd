class_name DisplaceVOLNative
extends GNVolBase
## Native-accelerated velocity-field displacement — delegates to GNNativeDisplaceVol (C++).

var _processor: RefCounted = null


func _init() -> void:
	super._init()
	node_type = "displace_native"
	node_description = "Displace density by a velocity field — native C++ accelerated."
	if ClassDB.class_exists("GNNativeDisplaceVol"):
		_processor = ClassDB.instantiate("GNNativeDisplaceVol")


func _init_ports() -> void:
	add_input("vol_in", GNFamily.Type.VOL, true, "Density volume")
	add_input("vel_in", GNFamily.Type.VOL, false, "Velocity volume")
	add_output("out", GNFamily.Type.VOL, "Displaced volume")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 1.0, 0.0, 100.0, 0.1,
		"Strength", "Displacement multiplier"))


func _cook(inputs: Array[GNData]) -> GNData:
	var den_vol: GNVolumeData = _get_input_vol(inputs, 0)
	var vel_vol: GNVolumeData = _get_input_vol(inputs, 1)
	if den_vol == null or vel_vol == null or not _processor:
		return null
	if not den_vol.has_volume() or not vel_vol.has_volume():
		return null

	var ctx := _get_ctx()
	if ctx.rd == null:
		return null

	var res: Vector3i = den_vol.resolution
	var den_raw: PackedByteArray = den_vol.read_full()
	var vel_raw: PackedByteArray = vel_vol.read_full()
	if den_raw.is_empty() or vel_raw.is_empty():
		return null

	var den_ch: int = den_vol.channels_per_voxel()
	var vel_ch: int = vel_vol.channels_per_voxel()
	var den_total: int = res.x * res.y * res.z * den_ch
	var vel_total: int = vel_vol.resolution.x * vel_vol.resolution.y * vel_vol.resolution.z * vel_ch

	var density := PackedFloat32Array()
	density.resize(den_total)
	for i in range(den_total):
		density[i] = den_raw.decode_float(i * 4)

	var velocity := PackedFloat32Array()
	velocity.resize(vel_total)
	for i in range(vel_total):
		velocity[i] = vel_raw.decode_float(i * 4)

	var displaced: PackedFloat32Array = _processor.process(density, velocity,
		res.x, res.y, res.z, den_ch, vel_ch, get_param_value("strength"))

	if displaced.is_empty():
		return null

	var out_vol := _create_volume(res, den_vol.format, den_vol.field_name)
	var bytes := PackedByteArray()
	bytes.resize(displaced.size() * 4)
	for i in range(displaced.size()):
		bytes.encode_float(i * 4, displaced[i])
	ctx.rd.texture_update(out_vol.rd_texture, 0, bytes)
	return out_vol
