class_name GNParticleData
extends GNData
## Output data type for POP operators.
## Wraps a GPU SSBO containing particle state (position, velocity, age, etc.).
## The buffer lives on the RenderingDevice — CPU readback only on explicit bridge ops.

## Attribute descriptor: offset in bytes and element type within the particle struct.
class AttribDesc:
	var offset: int     ## Byte offset from start of particle struct
	var type: String    ## "float", "vec2", "vec3", "vec4"

	func _init(p_offset: int, p_type: String) -> void:
		offset = p_offset
		type = p_type

	func byte_size() -> int:
		match type:
			"float": return 4
			"vec2":  return 8
			"vec3":  return 12
			"vec4":  return 16
		return 4


## GPU storage buffer RID holding the particle array.
var rd_buffer: RID = RID()

## Number of currently alive particles.
var particle_count: int = 0

## Maximum allocated particle capacity.
var max_particles: int = 0

## Bytes per particle (stride).
var stride: int = 0

## Named attribute layout: name → AttribDesc.
## Standard attributes: "pos" (vec4), "vel" (vec4), "color" (vec4),
## "age" (float), "life" (float), "mass" (float), "pscale" (float).
var attribute_layout: Dictionary = {}

## World-space bounding box of the particle cloud (estimated).
var bounds: AABB = AABB()


func get_family() -> GNFamily.Type:
	return GNFamily.Type.POP


func invalidate() -> void:
	super.invalidate()
	particle_count = 0


func duplicate_data() -> GNData:
	if rd_buffer == RID() or particle_count == 0:
		return _make_empty()
	var ctx := GNGpuContext.get_context()
	var byte_size: int = max_particles * stride
	var new_buf: RID = ctx.create_buffer(byte_size)
	# GPU-to-GPU copy
	if ctx.rd != null:
		ctx.rd.buffer_copy(rd_buffer, new_buf, 0, 0, byte_size)
	var copy := GNParticleData.new()
	copy.valid = valid
	copy.timestamp = timestamp
	copy.rd_buffer = new_buf
	copy.particle_count = particle_count
	copy.max_particles = max_particles
	copy.stride = stride
	copy.attribute_layout = attribute_layout.duplicate(true)
	copy.bounds = bounds
	return copy


## Returns byte offset for a named attribute, or -1 if not found.
func get_attrib_offset(attrib_name: String) -> int:
	var desc: AttribDesc = attribute_layout.get(attrib_name, null)
	if desc == null:
		return -1
	return desc.offset


## Returns true if this data has a valid GPU buffer.
func has_particles() -> bool:
	return rd_buffer.is_valid() and particle_count > 0


## Reads back particle positions to CPU as PackedVector3Array (expensive).
## Used by POPtoSOP bridge and viewer preview.
func read_positions() -> PackedVector3Array:
	if not has_particles():
		return PackedVector3Array()
	var ctx := GNGpuContext.get_context()
	var byte_size: int = particle_count * stride
	var raw: PackedByteArray = ctx.read_buffer(rd_buffer, byte_size)
	var pos_offset: int = get_attrib_offset("pos")
	if pos_offset < 0:
		return PackedVector3Array()
	var result := PackedVector3Array()
	result.resize(particle_count)
	for i in range(particle_count):
		var base: int = i * stride + pos_offset
		var x: float = raw.decode_float(base)
		var y: float = raw.decode_float(base + 4)
		var z: float = raw.decode_float(base + 8)
		result[i] = Vector3(x, y, z)
	return result


## Reads back a float attribute per particle to CPU.
func read_float_attrib(attrib_name: String) -> PackedFloat32Array:
	if not has_particles():
		return PackedFloat32Array()
	var ctx := GNGpuContext.get_context()
	var byte_size: int = particle_count * stride
	var raw: PackedByteArray = ctx.read_buffer(rd_buffer, byte_size)
	var off: int = get_attrib_offset(attrib_name)
	if off < 0:
		return PackedFloat32Array()
	var result := PackedFloat32Array()
	result.resize(particle_count)
	for i in range(particle_count):
		result[i] = raw.decode_float(i * stride + off)
	return result


## Frees the GPU buffer.  Call when this data is no longer needed.
func free_gpu() -> void:
	if rd_buffer.is_valid():
		GNGpuContext.get_context().free_rid(rd_buffer)
		rd_buffer = RID()


func _make_empty() -> GNParticleData:
	var e := GNParticleData.new()
	e.valid = false
	return e
