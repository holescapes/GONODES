class_name HostInPOP
extends GNPopBase
## Receives particle data from the host application via the LibGodot C API.
##
## The host calls gonodes_set_input_particles() to push per-particle attribute
## arrays (positions, velocities, colors, ages, etc.).
## GNEmbeddedHost flushes the data into this node via _set_host_particles().
##
## Usage: Place in a patch, set the node ID, and wire output to downstream POPs.
## The host references this node by its ID string.

## Host-provided particle arrays (CPU).
var _host_positions: PackedVector3Array = PackedVector3Array()
var _host_velocities: PackedVector3Array = PackedVector3Array()
var _host_colors: PackedColorArray = PackedColorArray()
var _host_ages: PackedFloat32Array = PackedFloat32Array()
var _host_lives: PackedFloat32Array = PackedFloat32Array()
var _host_pscales: PackedFloat32Array = PackedFloat32Array()
var _host_dirty: bool = false

## GPU zero-copy path: native SSBO handle from the host.
var _host_gpu_handle: int = 0
var _host_gpu_count: int = 0
var _host_gpu_stride: int = 0
var _host_gpu_buffer_size: int = 0
var _host_gpu_dirty: bool = false


func _init() -> void:
	node_type = "host_in_pop"
	time_dependent = true


func _init_ports() -> void:
	add_output("out", GNFamily.Type.POP, "Particles received from host")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "", "Label",
		"Optional label for this input in the host's UI"))
	add_parameter(GNParameter.create_int("max_particles", 100000, 1, 10000000,
		"Max Particles", "Maximum particle pool size"))


## Called by GNEmbeddedHost._flush_inputs() with the host's particle data.
func _set_host_particles(positions: PackedVector3Array,
		velocities: PackedVector3Array, colors: PackedColorArray,
		ages: PackedFloat32Array, lives: PackedFloat32Array,
		pscales: PackedFloat32Array) -> void:
	_host_positions = positions
	_host_velocities = velocities
	_host_colors = colors
	_host_ages = ages
	_host_lives = lives
	_host_pscales = pscales
	_host_dirty = true
	mark_dirty()


## Called by GNEmbeddedHost._flush_inputs() with a native GPU SSBO handle.
## Zero-copy: the handle is used directly — no CPU upload or readback.
## Requires shared GPU context between host and GONODES.
func _set_host_particles_gpu(handle: int, count: int, stride: int,
		buffer_size: int) -> void:
	_host_gpu_handle = handle
	_host_gpu_count = count
	_host_gpu_stride = stride
	_host_gpu_buffer_size = buffer_size
	_host_gpu_dirty = true
	_host_dirty = false  # GPU path supersedes CPU path
	mark_dirty()


func _cook(_inputs: Array[GNData]) -> GNData:
	# GPU zero-copy path: native SSBO from shared GPU context.
	if _host_gpu_dirty and _host_gpu_handle != 0:
		var pop := GNParticleData.new()
		pop.particle_count = _host_gpu_count
		pop.max_particles = maxi(_host_gpu_count, get_param_value("max_particles"))
		pop.is_cpu = false
		pop.stride = _host_gpu_stride
		# Wrap the external native SSBO handle.
		var ctx := _get_ctx()
		if ctx != null:
			var buf: RID = ctx.create_buffer_from_native(_host_gpu_handle,
				_host_gpu_buffer_size)
			if buf.is_valid():
				pop.rd_buffer = buf
		_host_gpu_dirty = false
		return pop

	# CPU path.
	if _host_positions.is_empty():
		return null

	var count: int = _host_positions.size()
	var pop := GNParticleData.new()
	pop.particle_count = count
	pop.max_particles = maxi(count, get_param_value("max_particles"))
	pop.is_cpu = true
	pop.cpu_positions = _host_positions.duplicate()
	pop.cpu_velocities = _host_velocities.duplicate() if _host_velocities.size() == count \
		else PackedVector3Array()
	pop.cpu_colors = _host_colors.duplicate() if _host_colors.size() == count \
		else PackedColorArray()
	pop.cpu_ages = _host_ages.duplicate() if _host_ages.size() == count \
		else PackedFloat32Array()
	pop.cpu_lives = _host_lives.duplicate() if _host_lives.size() == count \
		else PackedFloat32Array()
	pop.cpu_pscales = _host_pscales.duplicate() if _host_pscales.size() == count \
		else PackedFloat32Array()

	# Upload to GPU SSBO if compute is available
	var ctx := _get_ctx()
	if ctx != null:
		var buf_data := _pack_standard_ssbo(pop)
		if not buf_data.is_empty():
			var buf: RID = ctx.rd.storage_buffer_create(buf_data.size(), buf_data)
			if buf.is_valid():
				pop.rd_buffer = buf
				pop.stride = STANDARD_STRIDE
				pop.attribute_layout = STANDARD_LAYOUT.duplicate()
				pop.is_cpu = false

	_host_dirty = false
	return pop


## Packs CPU particle arrays into stdard SSBO layout (64 bytes/particle).
func _pack_standard_ssbo(pop: GNParticleData) -> PackedByteArray:
	var count := pop.particle_count
	var buf := PackedByteArray()
	buf.resize(count * STANDARD_STRIDE)
	for i in range(count):
		var off := i * STANDARD_STRIDE
		# pos (vec4: xyz + w=0)
		var p := pop.cpu_positions[i] if i < pop.cpu_positions.size() else Vector3.ZERO
		buf.encode_float(off, p.x)
		buf.encode_float(off + 4, p.y)
		buf.encode_float(off + 8, p.z)
		buf.encode_float(off + 12, 0.0)
		# vel (vec4: xyz + w=0)
		var v := pop.cpu_velocities[i] if i < pop.cpu_velocities.size() else Vector3.ZERO
		buf.encode_float(off + 16, v.x)
		buf.encode_float(off + 20, v.y)
		buf.encode_float(off + 24, v.z)
		buf.encode_float(off + 28, 0.0)
		# color (vec4: rgba)
		var c := pop.cpu_colors[i] if i < pop.cpu_colors.size() else Color.WHITE
		buf.encode_float(off + 32, c.r)
		buf.encode_float(off + 36, c.g)
		buf.encode_float(off + 40, c.b)
		buf.encode_float(off + 44, c.a)
		# age, life, mass, pscale
		buf.encode_float(off + 48, pop.cpu_ages[i] if i < pop.cpu_ages.size() else 0.0)
		buf.encode_float(off + 52, pop.cpu_lives[i] if i < pop.cpu_lives.size() else 1.0)
		buf.encode_float(off + 56, 1.0)  # mass
		buf.encode_float(off + 60, pop.cpu_pscales[i] if i < pop.cpu_pscales.size() else 1.0)
	return buf
