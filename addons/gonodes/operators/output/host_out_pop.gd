class_name HostOutPOP
extends GNOutBase
## Exports particle data to the host application via the LibGodot C API.
##
## Takes a POP input and makes its particle attributes available to the host
## through gonodes_get_output_particles().  GNEmbeddedHost._collect_outputs()
## calls _get_host_particles() each frame to publish the data.

## Cached particle arrays for the host.
var _output_positions: PackedFloat32Array = PackedFloat32Array()
var _output_velocities: PackedFloat32Array = PackedFloat32Array()
var _output_colors: PackedFloat32Array = PackedFloat32Array()
var _output_ages: PackedFloat32Array = PackedFloat32Array()
var _output_count: int = 0

## GPU zero-copy: cached native SSBO handle.
var _output_gpu_handle: int = 0
var _output_gpu_stride: int = 0
var _output_gpu_buffer_size: int = 0
var _has_gpu_output: bool = false


func _init() -> void:
	node_type = "host_out_pop"
	is_sink = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.POP, false, "Particle data to export to host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this output in the host's UI"))


func _cook(inputs: Array[GNData]) -> GNData:
	_output_positions = PackedFloat32Array()
	_output_velocities = PackedFloat32Array()
	_output_colors = PackedFloat32Array()
	_output_ages = PackedFloat32Array()
	_output_count = 0
	_output_gpu_handle = 0
	_output_gpu_stride = 0
	_output_gpu_buffer_size = 0
	_has_gpu_output = false

	if inputs.is_empty() or inputs[0] == null:
		return null

	var pop_in: GNParticleData = inputs[0] as GNParticleData if inputs[0] is GNParticleData else null
	if pop_in == null or pop_in.particle_count == 0:
		return null

	_output_count = pop_in.particle_count

	# GPU zero-copy: extract native SSBO handle (no CPU readback).
	if not pop_in.is_cpu and pop_in.rd_buffer.is_valid():
		var ctx := GNGpuContext.get_singleton()
		if ctx != null and ctx.rd != null:
			_output_gpu_handle = ctx.rd.buffer_get_native_handle(pop_in.rd_buffer)
			_output_gpu_stride = pop_in.stride
			_output_gpu_buffer_size = pop_in.particle_count * pop_in.stride
			_has_gpu_output = _output_gpu_handle != 0

	# CPU fallback for hosts without shared GPU context.
	if pop_in.is_cpu:
		_extract_cpu(pop_in)
	elif pop_in.rd_buffer.is_valid():
		_extract_gpu(pop_in)

	return null


## Extract from CPU-mode particle data.
func _extract_cpu(pop: GNParticleData) -> void:
	var count := pop.particle_count
	# Positions → flat xyz
	_output_positions.resize(count * 3)
	for i in range(mini(count, pop.cpu_positions.size())):
		_output_positions[i * 3] = pop.cpu_positions[i].x
		_output_positions[i * 3 + 1] = pop.cpu_positions[i].y
		_output_positions[i * 3 + 2] = pop.cpu_positions[i].z
	# Velocities → flat xyz
	_output_velocities.resize(count * 3)
	for i in range(mini(count, pop.cpu_velocities.size())):
		_output_velocities[i * 3] = pop.cpu_velocities[i].x
		_output_velocities[i * 3 + 1] = pop.cpu_velocities[i].y
		_output_velocities[i * 3 + 2] = pop.cpu_velocities[i].z
	# Colors → flat rgba
	_output_colors.resize(count * 4)
	for i in range(mini(count, pop.cpu_colors.size())):
		_output_colors[i * 4] = pop.cpu_colors[i].r
		_output_colors[i * 4 + 1] = pop.cpu_colors[i].g
		_output_colors[i * 4 + 2] = pop.cpu_colors[i].b
		_output_colors[i * 4 + 3] = pop.cpu_colors[i].a
	# Ages → flat
	_output_ages = pop.cpu_ages.duplicate()


## Extract from GPU SSBO — readback + unpack standard layout.
func _extract_gpu(pop: GNParticleData) -> void:
	var ctx := GNGpuContext.get_singleton()
	if ctx == null or ctx.rd == null:
		return
	var byte_data: PackedByteArray = ctx.rd.buffer_get_data(pop.rd_buffer)
	if byte_data.is_empty():
		return

	var count := pop.particle_count
	var stride := pop.stride if pop.stride > 0 else 64
	_output_positions.resize(count * 3)
	_output_velocities.resize(count * 3)
	_output_colors.resize(count * 4)
	_output_ages.resize(count)

	for i in range(count):
		var off := i * stride
		if off + stride > byte_data.size():
			break
		# pos (vec4 at offset 0)
		_output_positions[i * 3] = byte_data.decode_float(off)
		_output_positions[i * 3 + 1] = byte_data.decode_float(off + 4)
		_output_positions[i * 3 + 2] = byte_data.decode_float(off + 8)
		# vel (vec4 at offset 16)
		_output_velocities[i * 3] = byte_data.decode_float(off + 16)
		_output_velocities[i * 3 + 1] = byte_data.decode_float(off + 20)
		_output_velocities[i * 3 + 2] = byte_data.decode_float(off + 24)
		# color (vec4 at offset 32)
		_output_colors[i * 4] = byte_data.decode_float(off + 32)
		_output_colors[i * 4 + 1] = byte_data.decode_float(off + 36)
		_output_colors[i * 4 + 2] = byte_data.decode_float(off + 40)
		_output_colors[i * 4 + 3] = byte_data.decode_float(off + 44)
		# age (float at offset 48)
		_output_ages[i] = byte_data.decode_float(off + 48)


## Called by GNEmbeddedHost._collect_outputs() to get particle data.
func _get_host_particles() -> Dictionary:
	return {
		"positions": _output_positions,
		"velocities": _output_velocities,
		"colors": _output_colors,
		"ages": _output_ages,
		"count": _output_count,
	}


## Called by GNEmbeddedHost._collect_outputs() for GPU zero-copy path.
## Returns the native SSBO handle directly — no CPU readback.
## Requires shared GPU context between host and GONODES.
func _get_host_particles_gpu() -> Dictionary:
	if not _has_gpu_output:
		return {}
	return {
		"handle": _output_gpu_handle,
		"count": _output_count,
		"stride": _output_gpu_stride,
		"buffer_size": _output_gpu_buffer_size,
	}
