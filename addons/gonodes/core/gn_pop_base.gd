class_name GNPopBase
extends GNNode
## Base class for all POP (Point Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.POP set automatically
##   • Default output port "out" of type POP
##   • Access to shared GNGpuContext for compute dispatch
##   • Standard particle attribute layout (pos, vel, color, age, life, mass, pscale)
##   • Input/output helpers for GNParticleData
##   • MultiMesh preview control for inline particle visualization

## Standard particle struct layout (std430):
##   vec4 pos;      // 0   (xyz = position, w = 0)
##   vec4 vel;      // 16  (xyz = velocity, w = 0)
##   vec4 color;    // 32  (rgba)
##   float age;     // 48
##   float life;    // 52
##   float mass;    // 56
##   float pscale;  // 60
## Total stride: 64 bytes
const STANDARD_STRIDE: int = 64

## Standard attribute layout matching the struct above.
static var STANDARD_LAYOUT: Dictionary = {}

static func _get_standard_layout() -> Dictionary:
	if STANDARD_LAYOUT.is_empty():
		STANDARD_LAYOUT["pos"]    = GNParticleData.AttribDesc.new(0, "vec4")
		STANDARD_LAYOUT["vel"]    = GNParticleData.AttribDesc.new(16, "vec4")
		STANDARD_LAYOUT["color"]  = GNParticleData.AttribDesc.new(32, "vec4")
		STANDARD_LAYOUT["age"]    = GNParticleData.AttribDesc.new(48, "float")
		STANDARD_LAYOUT["life"]   = GNParticleData.AttribDesc.new(52, "float")
		STANDARD_LAYOUT["mass"]   = GNParticleData.AttribDesc.new(56, "float")
		STANDARD_LAYOUT["pscale"] = GNParticleData.AttribDesc.new(60, "float")
	return STANDARD_LAYOUT


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.POP
	# NOT time_dependent by default — only simulation operators (Source, Force,
	# Turbulence, Collision, Attract, Advect) set this to true individually.
	# Data-transform nodes (Instance, Render, ParticleState) don't need it.


func requires_compute() -> bool:
	return true


func has_cpu_fallback() -> bool:
	return true


func supported_renderers() -> PackedStringArray:
	return PackedStringArray(["forward_plus", "mobile"])


func initialize(p_id: String) -> void:
	family = GNFamily.Type.POP
	super.initialize(p_id)


func _init_ports() -> void:
	add_output("out", GNFamily.Type.POP, "Particle data output")


# ═══════════════════════════════════════════════════════════════════════════════
# GPU Context Access
# ═══════════════════════════════════════════════════════════════════════════════

func _get_ctx() -> GNGpuContext:
	return GNGpuContext.get_context()


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts GNParticleData from inputs at [param port].
func _get_input_pop(inputs: Array[GNData], port: int = 0) -> GNParticleData:
	if port < inputs.size() and inputs[port] is GNParticleData:
		return inputs[port] as GNParticleData
	return null


func update_preview_control(control: Control) -> void:
	if control is Label:
		(control as Label).text = cached_output.get_preview_text() if cached_output != null else ""


func display_in_viewer(viewer) -> void:
	if cached_output is GNParticleData:
		var pd: GNParticleData = cached_output as GNParticleData
		if pd.particle_count > 0:
			viewer.show_pop_particles(pd)
			return
	viewer.show_info("No POP output", "")


# ═══════════════════════════════════════════════════════════════════════════════
# Output Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Allocates a fresh GNParticleData with a GPU buffer for [param max_count] particles.
## Uses the standard attribute layout.
func _allocate_particles(max_count: int) -> GNParticleData:
	var ctx := _get_ctx()
	var byte_size: int = max_count * STANDARD_STRIDE
	var buf: RID = ctx.create_buffer(byte_size)
	var data := GNParticleData.new()
	data.rd_buffer = buf
	data.max_particles = max_count
	data.particle_count = 0
	data.stride = STANDARD_STRIDE
	data.attribute_layout = _get_standard_layout().duplicate(true)
	return data


## Encodes push constants for particle compute shaders.
## Override to add operator-specific uniforms.
func _encode_push_constants(params: Dictionary) -> PackedByteArray:
	var buf := PackedByteArray()
	for key in params:
		var val = params[key]
		if val is float:
			buf.append_array(_encode_float(val))
		elif val is int:
			buf.append_array(_encode_int(val))
		elif val is Vector3:
			buf.append_array(_encode_float(val.x))
			buf.append_array(_encode_float(val.y))
			buf.append_array(_encode_float(val.z))
			buf.append_array(_encode_float(0.0))  # pad to vec4
	return buf


func _encode_float(v: float) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_float(0, v)
	return b


func _encode_int(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_s32(0, v)
	return b


# ═══════════════════════════════════════════════════════════════════════════════
# Workgroup Calculation
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the number of workgroups needed for [param count] particles
## with [param local_size] threads per group. 
func _workgroups(count: int, local_size: int = 256) -> int:
	return ceili(float(count) / float(local_size))


# ═══════════════════════════════════════════════════════════════════════════════
# CPU Fallback Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Allocates a CPU-side GNParticleData with arrays pre-sized for [param max_count].
func _allocate_particles_cpu(max_count: int) -> GNParticleData:
	var data := GNParticleData.new()
	data.is_cpu = true
	data.max_particles = max_count
	data.particle_count = 0
	data.stride = STANDARD_STRIDE
	data.attribute_layout = _get_standard_layout().duplicate(true)
	data.cpu_positions.resize(max_count)
	data.cpu_velocities.resize(max_count)
	data.cpu_colors.resize(max_count)
	data.cpu_ages.resize(max_count)
	data.cpu_lives.resize(max_count)
	data.cpu_masses.resize(max_count)
	data.cpu_pscales.resize(max_count)
	return data


## Safely extracts CPU-capable GNParticleData from inputs at [param port].
func _get_input_pop_cpu(inputs: Array[GNData], port: int = 0) -> GNParticleData:
	if port < inputs.size() and inputs[port] is GNParticleData:
		var pd := inputs[port] as GNParticleData
		if pd.is_cpu:
			return pd
	return null



