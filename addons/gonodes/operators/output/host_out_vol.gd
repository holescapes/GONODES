class_name HostOutVOL
extends GNOutBase
## Exports volumetric data to the host application via the LibGodot C API.
##
## Takes a VOL input and makes its voxel data available to the host
## through gonodes_get_output_volume().  GNEmbeddedHost._collect_outputs()
## calls _get_host_volume() each frame to publish the data.

## Cached volume data for the host.
var _output_data: PackedFloat32Array = PackedFloat32Array()
var _output_resolution: Vector3i = Vector3i.ZERO
var _output_channels: int = 1
var _output_field: String = ""

## GPU zero-copy: cached native 3D texture handle.
var _output_gpu_handle: int = 0
var _output_gpu_format: int = 0
var _has_gpu_output: bool = false


func _init() -> void:
	node_type = "host_out_vol"
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.VOL, false, "Volume data to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	_output_data = PackedFloat32Array()
	_output_resolution = Vector3i.ZERO
	_output_channels = 1
	_output_field = ""
	_output_gpu_handle = 0
	_output_gpu_format = 0
	_has_gpu_output = false

	if inputs.is_empty() or inputs[0] == null:
		return null

	var vol_in: GNVolumeData = inputs[0] as GNVolumeData if inputs[0] is GNVolumeData else null
	if vol_in == null:
		return null

	_output_resolution = vol_in.resolution
	_output_channels = vol_in.channel_count
	_output_field = vol_in.field_name

	# GPU zero-copy: extract native handle directly (no CPU readback).
	if not vol_in.is_cpu and vol_in.rd_texture.is_valid():
		var ctx := GNGpuContext.get_singleton()
		if ctx != null and ctx.rd != null:
			_output_gpu_handle = ctx.rd.texture_get_native_handle(vol_in.rd_texture)
			_output_gpu_format = vol_in.data_format
			_has_gpu_output = _output_gpu_handle != 0

	# CPU fallback: readback for hosts without shared GPU context.
	if vol_in.is_cpu:
		_output_data = vol_in.cpu_data.duplicate()
	elif vol_in.rd_texture.is_valid():
		var ctx := GNGpuContext.get_singleton()
		if ctx != null and ctx.rd != null:
			var byte_data: PackedByteArray = ctx.rd.texture_get_data(vol_in.rd_texture, 0)
			_output_data = byte_data.to_float32_array()

	return null


## Called by GNEmbeddedHost._collect_outputs() to get volume data.
func _get_host_volume() -> Dictionary:
	return {
		"data": _output_data,
		"resolution": _output_resolution,
		"channels": _output_channels,
		"field": _output_field,
	}


## Called by GNEmbeddedHost._collect_outputs() for GPU zero-copy path.
## Returns the native 3D texture handle directly — no CPU readback.
## Requires shared GPU context between host and GONODES.
func _get_host_volume_gpu() -> Dictionary:
	if not _has_gpu_output:
		return {}
	return {
		"handle": _output_gpu_handle,
		"width": _output_resolution.x,
		"height": _output_resolution.y,
		"depth": _output_resolution.z,
		"channels": _output_channels,
		"format": _output_gpu_format,
		"field": _output_field,
	}
