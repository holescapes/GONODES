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



