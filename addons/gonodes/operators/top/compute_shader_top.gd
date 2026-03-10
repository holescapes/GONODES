class_name ComputeShaderTOP
extends GNTopBase
## GPU compute shader TOP using Godot's RenderingDevice API.
##
## Runs a user-written GLSL 450 compute shader that writes to a storage image.
## Input textures from upstream TOPs are available as sampler2D uniforms.
##
## The shader must write output pixels to [code]image2D gn_output[/code]
## (set 0, binding 0).  Push constants provide built-in values (time, frame,
## resolution) and any additional float/int fields become inspector parameters.
##
## Binding layout:
##   set 0, binding 0 — image2D gn_output  (rgba8 storage, write)
##   set 1, binding N — sampler2D gn_tex<N> (input textures, read)
##   push_constant    — PushConstants struct (built-in + user params)
##
## Reserved push constant names (auto-bound, no inspector param created):
##   gn_time   — elapsed time in seconds
##   gn_frame  — current frame number (as float)
##   gn_res_x  — output width in pixels
##   gn_res_y  — output height in pixels


const DEFAULT_COMPUTE_CODE := \
"""#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// ─── GONODES Auto-bound ──────────────────────────────────
// Output storage texture (set 0, binding 0 — always present).
layout(rgba8, set = 0, binding = 0) uniform image2D gn_output;

// Input textures — add gn_tex<N> samplers to auto-create input ports.
// layout(set = 1, binding = 0) uniform sampler2D gn_tex0;

// Push constants — built-in fields are auto-bound by GONODES.
// Add your own float/int fields AFTER the four gn_* fields
// to create inspector parameters automatically.
layout(push_constant, std430) uniform PushConstants {
	float gn_time;
	float gn_frame;
	float gn_res_x;
	float gn_res_y;
	// float speed;  // ← uncomment to add a "speed" parameter
} pc;

void main() {
	ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(gn_output);
	if (coords.x >= size.x || coords.y >= size.y) return;

	vec2 uv = vec2(coords) / vec2(size);
	float t = pc.gn_time;

	// Animated rainbow gradient
	vec3 col = 0.5 + 0.5 * cos(t + uv.xyx + vec3(0.0, 2.0, 4.0));
	imageStore(gn_output, coords, vec4(col, 1.0));
}
"""

## Push constant field names that are auto-bound (not exposed as params).
const _RESERVED_PC_NAMES: Array = ["gn_time", "gn_frame", "gn_res_x", "gn_res_y"]


# ═══════════════════════════════════════════════════════════════════════════════
# Parsed Push Constant Field
# ═══════════════════════════════════════════════════════════════════════════════

class _PCField:
	var field_name: String
	var field_type: String          # "float", "int", or "uint"
	var default_value: float        # stored as float; cast to int when packing

	func _init(p_name: String, p_type: String, p_default: float = 0.0) -> void:
		field_name = p_name
		field_type = p_type
		default_value = p_default


# ═══════════════════════════════════════════════════════════════════════════════
# RenderingDevice State
# ═══════════════════════════════════════════════════════════════════════════════

var _rd: RenderingDevice = null

var _shader_rid: RID = RID()
var _pipeline_rid: RID = RID()

## Output storage texture on the local RD.
var _output_tex_rid: RID = RID()
var _output_uniform_set: RID = RID()

## Reusable linear-clamp sampler for all input textures.
var _sampler_rid: RID = RID()

## Per-input-slot texture RIDs (recreated when input dimensions change).
var _input_tex_rids: Array[RID] = []
var _input_tex_sizes: Array[Vector2i] = []
var _input_uniform_set: RID = RID()

## CPU-side ImageTexture used to feed _cached_tex_data after readback.
var _output_image_texture: ImageTexture = null

## Last successfully compiled code (avoids redundant recompiles).
var _last_compiled_code: String = ""
var _shader_ok: bool = false

## Current output texture size on the local RD.
var _last_output_size: Vector2i = Vector2i.ZERO

## All parsed push-constant fields in declaration order (reserved + user).
var _pc_fields: Array = []           # Array[_PCField]

## Names of user-defined push constant params (excludes reserved gn_* names).
var _dynamic_param_names: PackedStringArray = PackedStringArray()

## Parsed workgroup size from the layout qualifier.
var _workgroup_size: Vector3i = Vector3i(8, 8, 1)

## Number of input texture slots parsed from sampler2D gn_tex<N> declarations.
var _tex_input_count: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	node_type = "compute"
	time_dependent = true
	node_description = "GPU compute shader (GLSL 450) with storage image output and auto-detected parameters."


func _init_ports() -> void:
	# Default template has no gn_tex sampler — ports rebuilt on shader compile.
	add_output("out", GNFamily.Type.TOP, "Compute output texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (enable for shaders using gn_time)"))
	add_parameter(GNParameter.create_bool("cook_once", false,
		"Cook Once", "Pulse: toggle ON to force a single cook, auto-resets to OFF"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"", "Output resolution in pixels"))
	add_parameter(GNParameter.create_string("shader_code",
		DEFAULT_COMPUTE_CODE.strip_edges(),
		"Shader Code", "GLSL 450 compute shader source (live recompile)"))


func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	if get_param_value("cook_once"):
		mark_dirty()
		set_param_value("cook_once", false)
	super._pre_cook(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_rd()


## Override from_dict to rebuild dynamic params from the restored shader code
## BEFORE trying to restore dynamic param values from the save file.
func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("shader_code")
	if not code.is_empty():
		_ensure_rd()
		if _rd != null:
			_compile_shader(code)
	# Now dynamic params exist — restore saved values.
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for param_name in params_dict:
			if param_name in ["resolution", "shader_code", "time_dependent", "cook_once"]:
				continue
			var param: GNParameter = parameters.get(param_name, null)
			if param != null:
				param.from_dict(params_dict[param_name])


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_rd()
	if _rd == null:
		return null

	# ── Resolution ──
	var res: Vector2i = get_param_value("resolution")
	var tex0 := _get_input_top(inputs, 0)
	if tex0 != null:
		res = tex0.resolution
	res = Vector2i(maxi(res.x, 1), maxi(res.y, 1))

	# ── Compile shader if code changed ──
	var code: String = get_param_value("shader_code")
	if code != _last_compiled_code:
		_compile_shader(code)
	if not _shader_ok:
		return _cached_tex_data

	# ── Ensure output storage texture ──
	_ensure_output_texture(res)
	if not _output_tex_rid.is_valid():
		return _cached_tex_data

	# ── Upload / update input textures ──
	_update_input_textures(inputs)

	# ── Build push-constant byte array ──
	var push_bytes := _build_push_constants(res)

	# ── Dispatch compute ──
	var groups_x := ceili(float(res.x) / float(_workgroup_size.x))
	var groups_y := ceili(float(res.y) / float(_workgroup_size.y))

	var cl := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(cl, _pipeline_rid)
	_rd.compute_list_bind_uniform_set(cl, _output_uniform_set, 0)
	if _input_uniform_set.is_valid():
		_rd.compute_list_bind_uniform_set(cl, _input_uniform_set, 1)
	if push_bytes.size() > 0:
		_rd.compute_list_set_push_constant(cl, push_bytes, push_bytes.size())
	_rd.compute_list_dispatch(cl, groups_x, groups_y, 1)
	_rd.compute_list_end()
	_rd.submit()
	_rd.sync()

	# ── Read back output → ImageTexture ──
	var output_bytes := _rd.texture_get_data(_output_tex_rid, 0)
	var img := Image.create_from_data(res.x, res.y, false, Image.FORMAT_RGBA8, output_bytes)
	if _output_image_texture == null:
		_output_image_texture = ImageTexture.create_from_image(img)
	else:
		_output_image_texture.update(img)

	_cached_tex_data.texture = _output_image_texture
	_cached_tex_data.resolution = res
	_cached_tex_data.valid = true
	_cached_tex_data.timestamp = Time.get_ticks_msec()
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# RenderingDevice Resource Management
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_rd() -> void:
	if _rd != null:
		return
	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		GNLogger.error("ComputeShaderTOP",
			"'%s' — failed to create local RenderingDevice" % id)
		return
	_cached_tex_data = GNTextureData.new()

	# Create a reusable sampler for input textures.
	var ss := RDSamplerState.new()
	ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler_rid = _rd.sampler_create(ss)


func _cleanup_rd() -> void:
	if _rd == null:
		return
	_free_input_textures()
	if _output_uniform_set.is_valid():
		_rd.free_rid(_output_uniform_set)
	if _output_tex_rid.is_valid():
		_rd.free_rid(_output_tex_rid)
	_free_shader_resources()
	if _sampler_rid.is_valid():
		_rd.free_rid(_sampler_rid)
	_rd.free()
	_rd = null


func _free_shader_resources() -> void:
	if _rd == null:
		return
	# Invalidate uniform sets that reference the old shader.
	if _output_uniform_set.is_valid():
		_rd.free_rid(_output_uniform_set)
		_output_uniform_set = RID()
	_free_input_textures()
	if _pipeline_rid.is_valid():
		_rd.free_rid(_pipeline_rid)
		_pipeline_rid = RID()
	if _shader_rid.is_valid():
		_rd.free_rid(_shader_rid)
		_shader_rid = RID()
	_last_output_size = Vector2i.ZERO


func _free_input_textures() -> void:
	if _rd == null:
		return
	if _input_uniform_set.is_valid():
		_rd.free_rid(_input_uniform_set)
		_input_uniform_set = RID()
	for rid in _input_tex_rids:
		if rid.is_valid():
			_rd.free_rid(rid)
	_input_tex_rids.clear()
	_input_tex_sizes.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# Shader Compilation
# ═══════════════════════════════════════════════════════════════════════════════

func _compile_shader(code: String) -> void:
	_free_shader_resources()

	if code.strip_edges().is_empty():
		GNLogger.warn("ComputeShaderTOP", "'%s' — empty shader code" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	# Compile GLSL → SPIR-V.
	var src := RDShaderSource.new()
	src.source_compute = code
	var spirv := _rd.shader_compile_spirv_from_source(src)
	var err: String = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not err.is_empty():
		GNLogger.error("ComputeShaderTOP",
			"'%s' — compile error:\n%s" % [id, err])
		_shader_ok = false
		_last_compiled_code = code
		return

	_shader_rid = _rd.shader_create_from_spirv(spirv)
	if not _shader_rid.is_valid():
		GNLogger.error("ComputeShaderTOP",
			"'%s' — failed to create shader from SPIR-V" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	_pipeline_rid = _rd.compute_pipeline_create(_shader_rid)
	if not _pipeline_rid.is_valid():
		GNLogger.error("ComputeShaderTOP",
			"'%s' — failed to create compute pipeline" % id)
		_rd.free_rid(_shader_rid)
		_shader_rid = RID()
		_shader_ok = false
		_last_compiled_code = code
		return

	_shader_ok = true
	_last_compiled_code = code

	# Parse shader metadata.
	_parse_workgroup_size(code)

	var new_tex_count := _count_shader_tex_inputs(code)
	if new_tex_count != _tex_input_count:
		_tex_input_count = new_tex_count
		_rebuild_tex_inputs(new_tex_count)

	_rebuild_push_constant_params(code)

	GNLogger.info("ComputeShaderTOP",
		"'%s' — shader compiled (%d chars, workgroup %s, %d tex inputs)" % [
		id, code.length(), str(_workgroup_size), _tex_input_count])


# ═══════════════════════════════════════════════════════════════════════════════
# Output Texture
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_output_texture(size: Vector2i) -> void:
	if size == _last_output_size and _output_tex_rid.is_valid():
		return

	# Free old (uniform set references the old texture, must go first).
	if _output_uniform_set.is_valid():
		_rd.free_rid(_output_uniform_set)
		_output_uniform_set = RID()
	if _output_tex_rid.is_valid():
		_rd.free_rid(_output_tex_rid)
		_output_tex_rid = RID()

	var tf := RDTextureFormat.new()
	tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	tf.width = size.x
	tf.height = size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	_output_tex_rid = _rd.texture_create(tf, RDTextureView.new())

	# Uniform set: set 0, binding 0 = image2D gn_output.
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = 0
	u.add_id(_output_tex_rid)
	_output_uniform_set = _rd.uniform_set_create([u], _shader_rid, 0)

	_last_output_size = size


# ═══════════════════════════════════════════════════════════════════════════════
# Input Textures
# ═══════════════════════════════════════════════════════════════════════════════

func _update_input_textures(inputs: Array[GNData]) -> void:
	if _tex_input_count == 0:
		return

	# Check whether any input changed size (requires texture + uniform-set rebuild).
	var needs_rebuild := _input_tex_rids.size() != _tex_input_count
	if not needs_rebuild:
		for i in range(_tex_input_count):
			var needed_size := _input_size_for(inputs, i)
			if i >= _input_tex_sizes.size() or _input_tex_sizes[i] != needed_size:
				needs_rebuild = true
				break

	if needs_rebuild:
		_free_input_textures()
		_create_input_textures(inputs)
	else:
		# Sizes match — just update the pixel data in-place.
		_upload_input_data(inputs)


func _input_size_for(inputs: Array[GNData], slot: int) -> Vector2i:
	if slot < inputs.size() and inputs[slot] is GNTextureData:
		var td: GNTextureData = inputs[slot] as GNTextureData
		if td.texture != null:
			var img := td.texture.get_image()
			if img != null:
				return Vector2i(img.get_width(), img.get_height())
	return Vector2i(1, 1)  # placeholder


func _create_input_textures(inputs: Array[GNData]) -> void:
	var uniforms: Array[RDUniform] = []

	for i in range(_tex_input_count):
		var img := _get_input_image(inputs, i)
		img.convert(Image.FORMAT_RGBA8)

		var tf := RDTextureFormat.new()
		tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		tf.width = img.get_width()
		tf.height = img.get_height()
		tf.depth = 1
		tf.array_layers = 1
		tf.mipmaps = 1
		tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		tf.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		)

		var tex_rid := _rd.texture_create(tf, RDTextureView.new(), [img.get_data()])
		_input_tex_rids.append(tex_rid)
		_input_tex_sizes.append(Vector2i(img.get_width(), img.get_height()))

		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = i
		u.add_id(_sampler_rid)
		u.add_id(tex_rid)
		uniforms.append(u)

	if uniforms.size() > 0:
		_input_uniform_set = _rd.uniform_set_create(uniforms, _shader_rid, 1)


func _upload_input_data(inputs: Array[GNData]) -> void:
	for i in range(_tex_input_count):
		if i >= _input_tex_rids.size():
			break
		var img := _get_input_image(inputs, i)
		img.convert(Image.FORMAT_RGBA8)
		_rd.texture_update(_input_tex_rid_at(i), 0, img.get_data())


func _input_tex_rid_at(idx: int) -> RID:
	if idx < _input_tex_rids.size():
		return _input_tex_rids[idx]
	return RID()


## Returns an Image for the given input slot, or a 1×1 white placeholder.
func _get_input_image(inputs: Array[GNData], slot: int) -> Image:
	if slot < inputs.size() and inputs[slot] is GNTextureData:
		var td: GNTextureData = inputs[slot] as GNTextureData
		if td.texture != null:
			var img := td.texture.get_image()
			if img != null:
				return img
	var placeholder := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color.WHITE)
	return placeholder


# ═══════════════════════════════════════════════════════════════════════════════
# Push Constants
# ═══════════════════════════════════════════════════════════════════════════════

func _build_push_constants(res: Vector2i) -> PackedByteArray:
	if _pc_fields.is_empty():
		return PackedByteArray()

	# SPIR-V pads push constant blocks to 16-byte (vec4) alignment.
	var raw_size := _pc_fields.size() * 4
	var padded_size := ceili(float(raw_size) / 16.0) * 16
	var bytes := PackedByteArray()
	bytes.resize(padded_size)

	var offset := 0
	for field in _pc_fields:
		var f: _PCField = field as _PCField
		match f.field_name:
			"gn_time":
				bytes.encode_float(offset, elapsed_time)
			"gn_frame":
				bytes.encode_float(offset, float(current_frame))
			"gn_res_x":
				bytes.encode_float(offset, float(res.x))
			"gn_res_y":
				bytes.encode_float(offset, float(res.y))
			_:
				# User parameter
				var val = get_param_value(f.field_name)
				if f.field_type == "int" or f.field_type == "uint":
					bytes.encode_s32(offset, int(val))
				else:
					bytes.encode_float(offset, float(val))
		offset += 4

	return bytes


# ═══════════════════════════════════════════════════════════════════════════════
# Shader Parsing
# ═══════════════════════════════════════════════════════════════════════════════

## Extracts local_size_x/y/z from the layout qualifier.
func _parse_workgroup_size(code: String) -> void:
	_workgroup_size = Vector3i(8, 8, 1)
	for line in code.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("//"):
			continue
		if s.find("local_size_x") == -1:
			continue
		# Found the layout line — extract values.
		var x_val := _extract_layout_int(s, "local_size_x")
		var y_val := _extract_layout_int(s, "local_size_y")
		var z_val := _extract_layout_int(s, "local_size_z")
		if x_val > 0:
			_workgroup_size.x = x_val
		if y_val > 0:
			_workgroup_size.y = y_val
		if z_val > 0:
			_workgroup_size.z = z_val
		break


## Extracts an integer value after "key = " in a layout(...) qualifier line.
static func _extract_layout_int(line: String, key: String) -> int:
	var pos := line.find(key)
	if pos == -1:
		return -1
	pos += key.length()
	# Skip whitespace and '='
	while pos < line.length() and (line[pos] == " " or line[pos] == "="):
		pos += 1
	var digits := ""
	while pos < line.length() and line[pos].is_valid_int():
		digits += line[pos]
		pos += 1
	if digits.is_empty():
		return -1
	return digits.to_int()


## Counts how many sampler2D gn_tex<N> declarations exist in the shader.
## Same approach as CustomShaderTOP._count_shader_tex_inputs().
static func _count_shader_tex_inputs(code: String) -> int:
	var max_idx: int = -1
	for line in code.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("//"):
			continue
		if s.find("sampler2D") == -1:
			continue
		var tex_pos := s.find("gn_tex")
		if tex_pos == -1:
			continue
		var digit_start := tex_pos + 6  # len("gn_tex")
		var digit_str := ""
		while digit_start < s.length() and s[digit_start].is_valid_int():
			digit_str += s[digit_start]
			digit_start += 1
		if not digit_str.is_empty():
			var idx := digit_str.to_int()
			if idx > max_idx:
				max_idx = idx
	return clampi(max_idx + 1, 0, 8)


## Rebuilds input ports to match the number of gn_tex samplers in the shader.
func _rebuild_tex_inputs(count: int) -> void:
	input_ports.clear()
	for i in range(count):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Texture input %d (gn_tex%d in shader)" % [i, i])
	GNLogger.info("ComputeShaderTOP",
		"'%s' input ports → %d (from shader uniforms)" % [id, count])
	ports_changed.emit(id)


## Parses the PushConstants block for user-defined float/int fields.
## Reserved gn_* fields are tracked but don't become inspector params.
func _rebuild_push_constant_params(code: String) -> void:
	var new_fields := _parse_push_constant_fields(code)

	# Snapshot old dynamic param values for preservation.
	var old_values: Dictionary = {}
	for p_name in _dynamic_param_names:
		var param := get_parameter(p_name)
		if param != null:
			old_values[p_name] = { "value": param.value, "type": param.value_type }

	# Remove old dynamic params.
	for p_name in _dynamic_param_names:
		if parameters.has(p_name):
			var param: GNParameter = parameters[p_name]
			if param.value_changed.is_connected(_on_parameter_changed):
				param.value_changed.disconnect(_on_parameter_changed)
			if param.mode_changed.is_connected(_on_parameter_mode_changed):
				param.mode_changed.disconnect(_on_parameter_mode_changed)
			parameters.erase(p_name)
	_dynamic_param_names.clear()

	_pc_fields = new_fields

	# Create inspector params for non-reserved fields.
	for field in new_fields:
		var f: _PCField = field as _PCField
		if f.field_name in _RESERVED_PC_NAMES:
			continue

		var param: GNParameter = null
		if f.field_type == "float":
			param = GNParameter.create_float(f.field_name, f.default_value,
				null, null, 0.01, "",
				"Push constant '%s'" % f.field_name)
		elif f.field_type == "int" or f.field_type == "uint":
			param = GNParameter.create_int(f.field_name, int(f.default_value),
				null, null, "",
				"Push constant '%s'" % f.field_name)

		if param == null:
			continue

		# Restore previous value if same name + type.
		if old_values.has(f.field_name):
			var old: Dictionary = old_values[f.field_name]
			if old["type"] == param.value_type:
				param.value = old["value"]
				param.resolved_value = old["value"]

		add_parameter(param)
		_dynamic_param_names.append(f.field_name)

	if not _dynamic_param_names.is_empty():
		GNLogger.info("ComputeShaderTOP",
			"'%s' dynamic params → %s" % [id, str(_dynamic_param_names)])
		parameters_changed.emit(id)


## Parses the push_constant block and returns an array of _PCField in
## declaration order.  Only float, int and uint fields are recognised.
static func _parse_push_constant_fields(code: String) -> Array:
	var fields: Array = []
	var inside_block := false

	for line in code.split("\n"):
		var s := line.strip_edges()

		# Detect start of the push_constant block.
		if not inside_block:
			if s.find("push_constant") != -1 and s.find("uniform") != -1:
				inside_block = true
			continue

		# Detect end of the block.
		if s.begins_with("}"):
			break

		# Skip comments / empty lines.
		if s.begins_with("//") or s.is_empty():
			continue

		# Parse "type name;" or "type name; // = default"
		var field := _parse_pc_field_line(s)
		if field != null:
			fields.append(field)

	return fields


## Parses a single line inside the PushConstants struct.
## Recognises: float, int, uint.  Ignores vec2/vec3/vec4/mat etc.
static func _parse_pc_field_line(line: String) -> _PCField:
	var s := line.strip_edges()

	var field_type := ""
	for candidate: String in ["float", "uint", "int"]:
		var pos := s.find(candidate)
		if pos != -1:
			# Make sure it's a standalone token (not part of another word).
			var end := pos + candidate.length()
			if end < s.length() and (s[end] == " " or s[end] == "\t"):
				field_type = candidate
				break
	if field_type.is_empty():
		return null

	# Extract name: first identifier after the type keyword.
	var start := s.find(field_type) + field_type.length()
	while start < s.length() and (s[start] == " " or s[start] == "\t"):
		start += 1
	var name := ""
	while start < s.length():
		var c := s[start]
		if c == "_" or c.is_valid_identifier():
			name += c
			start += 1
		else:
			break
	if name.is_empty():
		return null

	# Optional default value from trailing comment: // = <value>
	var def_val := 0.0
	var comment_pos := s.find("//")
	if comment_pos != -1:
		var comment := s.substr(comment_pos + 2).strip_edges()
		if comment.begins_with("="):
			var val_str := comment.substr(1).strip_edges().rstrip(";").strip_edges()
			if val_str.is_valid_float():
				def_val = val_str.to_float()

	return _PCField.new(name, field_type, def_val)
