class_name HostInVOL
extends GNVolBase
## Receives volumetric data from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_volume() to push a 3D voxel grid.
## GNEmbeddedHost flushes the data into this node via _set_host_volume().
##
## Usage: Place in a patch, set the node ID, and wire output to downstream VOLs.
## The host references this node by its ID string.

## Host-provided voxel data (CPU).
var _host_data: PackedFloat32Array = PackedFloat32Array()
var _host_resolution: Vector3i = Vector3i.ZERO
var _host_channels: int = 1
var _host_dirty: bool = false

## GPU zero-copy path: native 3D texture handle from the host.
var _host_gpu_handle: int = 0
var _host_gpu_resolution: Vector3i = Vector3i.ZERO
var _host_gpu_channels: int = 1
var _host_gpu_format: int = 0
var _host_gpu_dirty: bool = false


func _init() -> void:
	node_type = "host_in_vol"
	family = GNFamily.Type.NET
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.VOL, "Volume received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this input in the host's UI"))
	add_parameter(GNParameter.create_string("field_name", "density", "Field Name",
		"Semantic label for the volume contents"))


## Called by GNEmbeddedHost._flush_inputs() with the host's volume data.
func _set_host_volume(data: PackedFloat32Array, res: Vector3i, channels: int) -> void:
	_host_data = data
	_host_resolution = res
	_host_channels = channels
	_host_dirty = true
	mark_dirty()


## Called by GNEmbeddedHost._flush_inputs() with a native GPU 3D texture handle.
## Zero-copy: the handle is used directly — no CPU upload or readback.
## Requires shared GPU context between host and GONODES.
func _set_host_volume_gpu(handle: int, res: Vector3i, channels: int, fmt: int) -> void:
	_host_gpu_handle = handle
	_host_gpu_resolution = res
	_host_gpu_channels = channels
	_host_gpu_format = fmt
	_host_gpu_dirty = true
	_host_dirty = false  # GPU path supersedes CPU path
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	var field: String = get_param_value("field_name")

	# GPU zero-copy path: native handle from shared GPU context.
	if _host_gpu_dirty and _host_gpu_handle != 0:
		var vol := GNVolumeData.new()
		vol.resolution = _host_gpu_resolution
		vol.channel_count = _host_gpu_channels
		vol.field_name = field
		vol.is_cpu = false
		vol.data_format = _host_gpu_format
		# Wrap the external native handle as a RenderingDevice texture.
		var ctx := _get_ctx()
		if ctx != null:
			var tex: RID = ctx.create_texture_3d_from_native(_host_gpu_handle,
				_host_gpu_resolution, _host_gpu_format)
			if tex.is_valid():
				vol.rd_texture = tex
		_host_gpu_dirty = false
		return vol

	# CPU path: upload host-provided voxel data.
	if _host_data.is_empty() or _host_resolution == Vector3i.ZERO:
		return null

	var vol := GNVolumeData.new()
	vol.resolution = _host_resolution
	vol.channel_count = _host_channels
	vol.field_name = field
	vol.is_cpu = true
	vol.cpu_data = _host_data.duplicate()

	# Upload to GPU if compute is available
	var ctx := _get_ctx()
	if ctx != null:
		var fmt: int = RenderingDevice.DATA_FORMAT_R32_SFLOAT if _host_channels == 1 \
			else RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
		var tex: RID = ctx.create_texture_3d(_host_resolution, fmt)
		if tex.is_valid():
			var byte_data := _host_data.to_byte_array()
			ctx.rd.texture_update(tex, 0, byte_data)
			vol.rd_texture = tex
			vol.data_format = fmt
			vol.is_cpu = false

	_host_dirty = false
	return vol
