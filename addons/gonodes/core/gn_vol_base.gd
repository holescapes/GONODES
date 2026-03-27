class_name GNVolBase
extends GNNode
## Base class for all VOL (Volume Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.VOL set automatically
##   • Default output port "out" of type VOL
##   • Access to shared GNGpuContext for compute dispatch
##   • 3D texture creation/pool helpers
##   • Input/output helpers for GNVolumeData
##   • Three-slice + MIP preview control

# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.VOL


func requires_compute() -> bool:
	return true


func has_cpu_fallback() -> bool:
	return true


func supported_renderers() -> PackedStringArray:
	return PackedStringArray(["forward_plus", "mobile"])


func initialize(p_id: String) -> void:
	family = GNFamily.Type.VOL
	super.initialize(p_id)


func _init_ports() -> void:
	add_output("out", GNFamily.Type.VOL, "Volume data output")


# ═══════════════════════════════════════════════════════════════════════════════
# GPU Context Access
# ═══════════════════════════════════════════════════════════════════════════════

func _get_ctx() -> GNGpuContext:
	return GNGpuContext.get_context()


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts GNVolumeData from inputs at [param port].
func _get_input_vol(inputs: Array[GNData], port: int = 0) -> GNVolumeData:
	if port < inputs.size() and inputs[port] is GNVolumeData:
		return inputs[port] as GNVolumeData
	return null


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


# ═══════════════════════════════════════════════════════════════════════════════
# Texture Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a fresh GNVolumeData with an allocated 3D texture.
func _create_volume(res: Vector3i,
		fmt: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT,
		p_field: String = "density") -> GNVolumeData:
	var ctx := _get_ctx()
	var tex: RID = ctx.create_texture_3d(res, fmt)
	var vd := GNVolumeData.new()
	vd.rd_texture = tex
	vd.resolution = res
	vd.data_format = fmt
	vd.field_name = p_field
	vd.channel_count = _channels_for_format(fmt)
	return vd


## Acquires a pooled texture wrapped in GNVolumeData.
func _acquire_volume(res: Vector3i,
		fmt: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT,
		p_field: String = "density") -> GNVolumeData:
	var ctx := _get_ctx()
	var tex: RID = ctx.acquire_texture_3d(res, fmt)
	var vd := GNVolumeData.new()
	vd.rd_texture = tex
	vd.resolution = res
	vd.data_format = fmt
	vd.field_name = p_field
	vd.channel_count = _channels_for_format(fmt)
	return vd


## Returns channel count for a given format.
func _channels_for_format(fmt: int) -> int:
	match fmt:
		RenderingDevice.DATA_FORMAT_R16_SFLOAT, \
		RenderingDevice.DATA_FORMAT_R32_SFLOAT:
			return 1
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, \
		RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT:
			return 4
	return 1


# ═══════════════════════════════════════════════════════════════════════════════
# Push Constants Helper
# ═══════════════════════════════════════════════════════════════════════════════

## Encodes a dictionary of named values into push constant bytes.
func _encode_push_constants(params: Dictionary) -> PackedByteArray:
	var buf := PackedByteArray()
	for key in params:
		var val = params[key]
		if val is float:
			buf.append_array(_f32(val))
		elif val is int:
			buf.append_array(_i32(val))
		elif val is Vector3:
			buf.append_array(_f32(val.x))
			buf.append_array(_f32(val.y))
			buf.append_array(_f32(val.z))
			buf.append_array(_f32(0.0))
		elif val is Vector3i:
			buf.append_array(_i32(val.x))
			buf.append_array(_i32(val.y))
			buf.append_array(_i32(val.z))
			buf.append_array(_i32(0))
	return buf


func _f32(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	return b


func _i32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_s32(0, v)
	return b


# ═══════════════════════════════════════════════════════════════════════════════
# Workgroup Calculation
# ═══════════════════════════════════════════════════════════════════════════════

## Returns workgroup counts for a 3D dispatch with local_size per axis.
func _workgroups_3d(res: Vector3i, local_size: int = 8) -> Vector3i:
	return Vector3i(
		ceili(float(res.x) / float(local_size)),
		ceili(float(res.y) / float(local_size)),
		ceili(float(res.z) / float(local_size))
	)


# ═══════════════════════════════════════════════════════════════════════════════
# CPU Fallback Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a CPU-side GNVolumeData with a pre-allocated float array.
func _create_volume_cpu(res: Vector3i,
		channels: int = 1,
		p_field: String = "density") -> GNVolumeData:
	var vd := GNVolumeData.new()
	vd.is_cpu = true
	vd.rd_texture = RID()
	vd.resolution = res
	vd.channel_count = channels
	vd.field_name = p_field
	vd.cpu_data.resize(res.x * res.y * res.z * channels)
	vd.cpu_data.fill(0.0)
	return vd


## Safely extracts CPU-capable GNVolumeData from inputs at [param port].
func _get_input_vol_cpu(inputs: Array[GNData], port: int = 0) -> GNVolumeData:
	if port < inputs.size() and inputs[port] is GNVolumeData:
		var vd := inputs[port] as GNVolumeData
		if vd.is_cpu:
			return vd
	return null


## Returns the linear index into a flat CPU volume array.
func _vol_idx(x: int, y: int, z: int, res: Vector3i, channels: int = 1) -> int:
	return (z * res.y * res.x + y * res.x + x) * channels


## Samples the CPU volume with clamped integer coordinates.
func _vol_sample(data: PackedFloat32Array, x: int, y: int, z: int,
		res: Vector3i, channels: int = 1) -> float:
	x = clampi(x, 0, res.x - 1)
	y = clampi(y, 0, res.y - 1)
	z = clampi(z, 0, res.z - 1)
	return data[_vol_idx(x, y, z, res, channels)]


## Trilinear sample of CPU volume at normalized [0,1] coordinates.
func _vol_sample_trilinear(data: PackedFloat32Array, uvw: Vector3,
		res: Vector3i, channels: int = 1) -> float:
	var fx: float = uvw.x * (res.x - 1)
	var fy: float = uvw.y * (res.y - 1)
	var fz: float = uvw.z * (res.z - 1)
	var x0: int = int(fx)
	var y0: int = int(fy)
	var z0: int = int(fz)
	var x1: int = mini(x0 + 1, res.x - 1)
	var y1: int = mini(y0 + 1, res.y - 1)
	var z1: int = mini(z0 + 1, res.z - 1)
	var xf: float = fx - x0
	var yf: float = fy - y0
	var zf: float = fz - z0
	var c000: float = _vol_sample(data, x0, y0, z0, res, channels)
	var c100: float = _vol_sample(data, x1, y0, z0, res, channels)
	var c010: float = _vol_sample(data, x0, y1, z0, res, channels)
	var c110: float = _vol_sample(data, x1, y1, z0, res, channels)
	var c001: float = _vol_sample(data, x0, y0, z1, res, channels)
	var c101: float = _vol_sample(data, x1, y0, z1, res, channels)
	var c011: float = _vol_sample(data, x0, y1, z1, res, channels)
	var c111: float = _vol_sample(data, x1, y1, z1, res, channels)
	var c00: float = lerpf(c000, c100, xf)
	var c10: float = lerpf(c010, c110, xf)
	var c01: float = lerpf(c001, c101, xf)
	var c11: float = lerpf(c011, c111, xf)
	var c0: float = lerpf(c00, c10, yf)
	var c1: float = lerpf(c01, c11, yf)
	return lerpf(c0, c1, zf)



