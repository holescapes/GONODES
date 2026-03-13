class_name GNVolumeData
extends GNData
## Output data type for VOL operators.
## Wraps a GPU 3D texture holding volumetric data (density, velocity, etc.).

## GPU 3D texture RID (lives on the shared RenderingDevice).
var rd_texture: RID = RID()

## Volume resolution in voxels.
var resolution: Vector3i = Vector3i(64, 64, 64)

## World-space bounding box of the volume.
var bounds: AABB = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1.0, 1.0, 1.0))

## RenderingDevice.DATA_FORMAT_* constant describing the texel format.
## Common formats:
##   DATA_FORMAT_R16_SFLOAT   — half-float density (2 bytes/voxel)
##   DATA_FORMAT_R32_SFLOAT   — float density (4 bytes/voxel)
##   DATA_FORMAT_R16G16B16A16_SFLOAT — half-float RGBA (8 bytes/voxel)
##   DATA_FORMAT_R32G32B32A32_SFLOAT — float RGBA (16 bytes/voxel)
var data_format: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT

## Number of channels (derived from format): 1 for R, 4 for RGBA.
var channel_count: int = 1

## Semantic label for the volume contents (e.g., "density", "velocity", "temperature").
var field_name: String = "density"


func get_family() -> GNFamily.Type:
	return GNFamily.Type.VOL


func invalidate() -> void:
	super.invalidate()


func duplicate_data() -> GNData:
	if not rd_texture.is_valid():
		return _make_empty()
	var ctx := GNGpuContext.get_context()
	var new_tex: RID = ctx.create_texture_3d(resolution, data_format)
	# GPU-to-GPU copy
	if ctx.rd != null:
		ctx.rd.texture_copy(rd_texture, new_tex,
			Vector3i.ZERO, Vector3i.ZERO,
			Vector3i(resolution.x, resolution.y, resolution.z),
			0, 0, 0, 0)
	var copy := GNVolumeData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.rd_texture = new_tex
	copy.resolution = resolution
	copy.bounds = bounds
	copy.data_format = data_format
	copy.channel_count = channel_count
	copy.field_name = field_name
	return copy


## Returns true if this data has a valid GPU texture.
func has_volume() -> bool:
	return rd_texture.is_valid()


## Returns the total number of voxels.
func voxel_count() -> int:
	return resolution.x * resolution.y * resolution.z


## Returns bytes per voxel based on the current format.
func bytes_per_voxel() -> int:
	match data_format:
		RenderingDevice.DATA_FORMAT_R16_SFLOAT:
			return 2
		RenderingDevice.DATA_FORMAT_R32_SFLOAT:
			return 4
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT:
			return 8
		RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT:
			return 16
	return 4


## Reads back a single Z-slice as a PackedByteArray (for viewer preview).
## Returns raw bytes for one XY plane at the given z index.
func read_slice_z(z: int) -> PackedByteArray:
	if not has_volume() or z < 0 or z >= resolution.z:
		return PackedByteArray()
	var ctx := GNGpuContext.get_context()
	if ctx.rd == null:
		return PackedByteArray()
	# Read the full 3D texture data and extract the requested slice
	var full_data: PackedByteArray = ctx.rd.texture_get_data(rd_texture, 0)
	var bpv: int = bytes_per_voxel()
	var slice_size: int = resolution.x * resolution.y * bpv
	var offset: int = z * slice_size
	if offset + slice_size > full_data.size():
		return PackedByteArray()
	return full_data.slice(offset, offset + slice_size)


## Reads back the full 3D texture data to CPU (expensive).
func read_full() -> PackedByteArray:
	if not has_volume():
		return PackedByteArray()
	var ctx := GNGpuContext.get_context()
	if ctx.rd == null:
		return PackedByteArray()
	return ctx.rd.texture_get_data(rd_texture, 0)


## Frees the GPU texture.
func free_gpu() -> void:
	if rd_texture.is_valid():
		GNGpuContext.get_context().free_rid(rd_texture)
		rd_texture = RID()


## Releases this texture back to the pool for reuse.
func release_to_pool() -> void:
	if rd_texture.is_valid():
		GNGpuContext.get_context().release_texture_3d(rd_texture, resolution, data_format)
		rd_texture = RID()


func _make_empty() -> GNVolumeData:
	var e := GNVolumeData.new()
	e.valid = false
	return e
