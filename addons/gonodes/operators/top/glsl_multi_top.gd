class_name GLSLMultiTOP
extends GNTopBase
## Multi-output fragment shader — write the SAME Godot Shading Language you
## already know from CustomShaderTOP, but assign to gn_out0, gn_out1, etc.
## to produce multiple output textures in a single operator.
##
## =============================================================================
## HOW TO WRITE THE SHADER
## =============================================================================
##
## Your code is identical to a CustomShaderTOP shader except you assign to
## gn_out0, gn_out1, ... gn_out7 instead of COLOR.  Each gn_outN creates an
## output port automatically.
##
##   shader_type canvas_item;
##   uniform sampler2D gn_tex0 : hint_default_white;
##   uniform float edge_strength = 5.0;
##
##   void fragment() {
##       vec4 src = texture(gn_tex0, UV);
##       float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));
##
##       gn_out0 = src;                                   // output 0: original
##       gn_out1 = vec4(vec3(luma), src.a);              // output 1: luminance
##       gn_out2 = vec4(fwidth(src.rgb) * edge_strength, 1.0); // output 2: edges
##   }
##
## Everything else works the same as CustomShaderTOP:
##   - uniform sampler2D gn_tex<N> -> auto-creates input ports
##   - uniform float/int/bool/vec2/vec4 -> auto-creates inspector parameters
##   - TIME, UV, SCREEN_PIXEL_SIZE -> built-in Godot uniforms
##   - gn_resolution -> auto-bound to output resolution
##
## =============================================================================
## SINGLE-PASS MRT vs MULTI-PASS FALLBACK
## =============================================================================
##
## On Forward+ and Mobile renderers (Vulkan), GLSLMultiTOP uses the
## RenderingDevice API to render ALL outputs in a SINGLE draw call via
## Multiple Render Targets (MRT).  Your shader is auto-transpiled from
## Godot Shading Language to GLSL 450 behind the scenes. You never see the
## raw GLSL. This is the same approach TouchDesigner's GLSL Multi TOP uses.
##
## On the Compatibility renderer (OpenGL / Web), RenderingDevice is not
## available.  GLSLMultiTOP falls back to multi-pass rendering: one
## canvas_item render pass per output.  This is N x the fragment cost but
## works everywhere including Web export.
##
## The fallback is AUTOMATIC. You never need to change your shader code.
## The operator logs which path it chose at initialization.
##
## =============================================================================
## GOTCHAS
## =============================================================================
##
## - MRT path transpiles canvas_item code to GLSL 450 automatically.  Basic
##   features (texture, mix, clamp, smoothstep, UV, TIME, dFdx/dFdy, fwidth)
##   work. Advanced features like SCREEN_TEXTURE or custom varyings are NOT
##   supported in MRT mode. Use CustomShaderTOP + SelectTOP for those.
##
## - On Compatibility renderer, the multi-pass fallback runs the shader N
##   times. For 2-4 outputs at <=1080p this is <1ms overhead.  For 8 outputs
##   at 4K, consider ComputeShaderTOP instead.
##
## - If you only assign gn_out0, this behaves identically to CustomShaderTOP
##   (single output, single pass) on any renderer.
##
## - The MRT path does a GPU->CPU readback per output (same as ComputeShaderTOP).
##   At 512x512 RGBA8, readback is ~1ms per output.
##
## - Maximum 8 outputs (gn_out0..gn_out7). Most GPUs support 8 MRT slots.


const DEFAULT_SHADER_CODE := """shader_type canvas_item;

// --- GONODES Multi-Output Shader ---
// Input textures: gn_tex<N> auto-creates input ports (up to 8).
uniform sampler2D gn_tex0 : hint_default_white;

// Your uniforms become inspector parameters automatically.
// uniform float brightness = 1.0;

void fragment() {
vec4 src = texture(gn_tex0, UV);
float luma = dot(src.rgb, vec3(0.299, 0.587, 0.114));

gn_out0 = src;                             // Output 0: original
gn_out1 = vec4(vec3(luma), src.a);        // Output 1: luminance
}
"""

const _RESERVED_UNIFORMS: Array = ["gn_resolution", "gn_output_index"]
const _MAX_OUTPUTS: int = 8

var _output_count: int = 1
var _last_compiled_code: String = ""
var _shader_ok: bool = false
var _dynamic_param_names: PackedStringArray = PackedStringArray()
var _use_mrt: bool = false

# -- MRT path (RenderingDevice) state --
var _rd: RenderingDevice = null
var _shader_rid: RID = RID()
var _pipeline_rid: RID = RID()
var _framebuffer_rid: RID = RID()
var _output_tex_rids: Array[RID] = []
var _last_mrt_size: Vector2i = Vector2i.ZERO
var _sampler_rid: RID = RID()
var _input_tex_rids: Array[RID] = []
var _input_tex_sizes: Array[Vector2i] = []
var _input_uniform_set: RID = RID()
var _output_image_textures: Array[ImageTexture] = []
var _vertex_buffer_rid: RID = RID()
var _vertex_array_rid: RID = RID()

# -- Fallback path (multi-pass SubViewport) state --
var _fb_shaders: Array[Shader] = []
var _fb_viewports: Array[SubViewport] = []
var _fb_materials: Array[ShaderMaterial] = []
var _fb_canvases: Array[ColorRect] = []

# -- Shared output texture data --
var _output_textures: Array[GNTextureData] = []


func _init() -> void:
	node_type = "glsl_multi"
	time_dependent = true


func _init_ports() -> void:
	add_input("in0", GNFamily.Type.TOP, false, "Texture input 0 (gn_tex0)", "Input 0")
	add_output("out0", GNFamily.Type.TOP, "Shader output 0 (gn_out0)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (for shaders using TIME)"))
	add_parameter(GNParameter.create_bool("cook_once", false,
		"Cook Once", "Pulse: force single cook, auto-resets"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"", "Output texture resolution"))
	add_parameter(GNParameter.create_string("shader_code", DEFAULT_SHADER_CODE.strip_edges(),
		"Shader Code", "Godot Shading Language. Assign to gn_out0..7 for multi-output"))


func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	if get_param_value("cook_once"):
		mark_dirty()
		set_param_value("cook_once", false)
	super._pre_cook(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_mrt()


func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("shader_code")
	if not code.is_empty():
		_output_count = _detect_output_count(code)
		_try_init_mrt()
		_compile_all(code)
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for param_name in params_dict:
			if param_name in ["resolution", "shader_code", "time_dependent", "cook_once"]:
				continue
			var param: GNParameter = parameters.get(param_name, null)
			if param != null:
				param.from_dict(params_dict[param_name])


# ===========================================================================
# Cook
# ===========================================================================

func _cook(inputs: Array[GNData]) -> GNData:
	var res := Vector2i(512, 512)
	if parameters.has("resolution"):
		res = get_param_value("resolution")
	var tex0: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex0 != null:
		res = tex0.resolution
	res = Vector2i(maxi(res.x, 1), maxi(res.y, 1))

	var code: String = get_param_value("shader_code")
	if code != _last_compiled_code:
		_output_count = _detect_output_count(code)
		_try_init_mrt()
		_compile_all(code)

	if not _shader_ok:
		return _cached_tex_data if _cached_tex_data != null else null

	if _use_mrt:
		return _cook_mrt(inputs, res)
	else:
		return _cook_fallback(inputs, res)


func get_output_data(port_index: int) -> GNData:
	if port_index >= 0 and port_index < _output_textures.size():
		return _output_textures[port_index]
	return _cached_tex_data


# ===========================================================================
# Output Detection -- scan for gn_out<N>
# ===========================================================================

static func _detect_output_count(code: String) -> int:
	var max_idx: int = 0
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("//"):
			continue
		var pos := 0
		while pos < stripped.length():
			var found := stripped.find("gn_out", pos)
			if found == -1:
				break
			var digit_start := found + 6
			var digit_str := ""
			while digit_start < stripped.length() and stripped[digit_start].is_valid_int():
				digit_str += stripped[digit_start]
				digit_start += 1
			if not digit_str.is_empty():
				var idx := digit_str.to_int()
				if idx > max_idx:
					max_idx = idx
			pos = found + 6
	return clampi(max_idx + 1, 1, _MAX_OUTPUTS)


# ===========================================================================
# Renderer Detection
# ===========================================================================

func _try_init_mrt() -> void:
	if _rd != null:
		_use_mrt = true
		return
	_rd = RenderingServer.create_local_rendering_device()
	if _rd != null:
		_use_mrt = true
		_cached_tex_data = GNTextureData.new()
		var ss := RDSamplerState.new()
		ss.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		ss.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		ss.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		ss.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		_sampler_rid = _rd.sampler_create(ss)
		_create_fullscreen_triangle()
		GNLogger.info("GLSLMultiTOP", "'%s' -- using single-pass MRT (RenderingDevice)" % id)
	else:
		_use_mrt = false
		GNLogger.info("GLSLMultiTOP", "'%s' -- using multi-pass fallback (Compatibility renderer)" % id)


# ===========================================================================
# #### MRT PATH (single-pass via RenderingDevice) ####
# ===========================================================================

const _VERT_GLSL := """#version 450

layout(location = 0) out vec2 UV;

void main() {
UV = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
gl_Position = vec4(UV * 2.0 - 1.0, 0.0, 1.0);
UV.y = 1.0 - UV.y;
}
"""


func _create_fullscreen_triangle() -> void:
	var dummy_data := PackedByteArray()
	dummy_data.resize(3 * 8)
	_vertex_buffer_rid = _rd.vertex_buffer_create(dummy_data.size(), dummy_data)
	var vf := RDVertexAttribute.new()
	vf.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	vf.location = 0
	vf.stride = 8
	vf.offset = 0
	_vertex_array_rid = _rd.vertex_array_create(3, _rd.vertex_format_create([vf]), [_vertex_buffer_rid])


## Transpiles user canvas_item code into GLSL 450 fragment shader.
## The user writes normal Godot Shading Language with gn_out0..N assignments.
## We produce proper layout(location=N) outputs, sampler bindings, and push
## constants so the RenderingDevice can execute it as a single-pass MRT draw.
func _transpile_to_glsl450(code: String) -> String:
	var lines := code.split("\n")
	var out_lines: PackedStringArray = PackedStringArray()

	out_lines.append("#version 450")
	out_lines.append("")
	out_lines.append("layout(location = 0) in vec2 UV;")
	out_lines.append("")

	# Output attachments
	for i in range(_output_count):
		out_lines.append("layout(location = %d) out vec4 gn_out%d;" % [i, i])
	out_lines.append("")

	var user_uniforms: Array = []
	var tex_bindings: Array = []

	var in_fragment := false
	var brace_depth := 0

	for line in lines:
		var stripped := line.strip_edges()

		if stripped.begins_with("shader_type"):
			continue

		if not in_fragment and stripped.begins_with("//"):
			continue

		# Parse uniform declarations
		if not in_fragment and stripped.find("uniform") != -1 and stripped.find(";") != -1:
			if stripped.find("sampler2D") != -1:
				var tex_name := _extract_tex_name(stripped)
				if not tex_name.is_empty():
					var idx := _extract_tex_index(tex_name)
					if idx >= 0:
						tex_bindings.append([idx, tex_name])
			else:
				var uinfo := _parse_uniform_for_transpile(stripped)
				if not uinfo.is_empty() and uinfo[1] not in _RESERVED_UNIFORMS:
					user_uniforms.append(uinfo)
			continue

		# Detect void fragment()
		if not in_fragment and stripped.find("void fragment") != -1:
			in_fragment = true
			out_lines.append("void main() {")
			var brace_pos := stripped.find("{")
			if brace_pos != -1:
				brace_depth = 1
			continue

		if in_fragment:
			for c in stripped:
				if c == "{":
					brace_depth += 1
				elif c == "}":
					brace_depth -= 1
			if brace_depth <= 0:
				out_lines.append("}")
				in_fragment = false
				continue
			var body_line := line.replace("COLOR", "gn_out0")
			out_lines.append(body_line)
			continue

		if not stripped.is_empty():
			out_lines.append(line)

	# Find insertion point (before void main)
	var insert_pos := 0
	for i in range(out_lines.size()):
		if out_lines[i].find("void main") != -1:
			insert_pos = i
			break

	var preamble: PackedStringArray = PackedStringArray()

	# Texture bindings
	for tb in tex_bindings:
		preamble.append("layout(set = 0, binding = %d) uniform sampler2D %s;" % [tb[0], tb[1]])
	if not tex_bindings.is_empty():
		preamble.append("")

	# Push constant block
	preamble.append("layout(push_constant, std430) uniform PushConstants {")
	preamble.append("\tvec2 gn_resolution;")
	preamble.append("\tfloat TIME;")
	preamble.append("\tfloat _pad0;")
	for uinfo in user_uniforms:
		preamble.append("\t%s %s;" % [uinfo[0], uinfo[1]])
	var total_fields := 4 + user_uniforms.size()
	var remainder := total_fields % 4
	if remainder != 0:
		for p in range(4 - remainder):
			preamble.append("\tfloat _pad%d;" % (p + 1))
	preamble.append("} pc;")
	preamble.append("")

	# Build result
	var result: PackedStringArray = PackedStringArray()
	for i in range(out_lines.size()):
		if i == insert_pos:
			result.append_array(preamble)
		result.append(out_lines[i])

	var final := "\n".join(result)

	# Replace standalone TIME with pc.TIME
	final = _replace_standalone_identifier(final, "TIME", "pc.TIME")
	# Replace user uniform names with pc.name
	for uinfo in user_uniforms:
		final = _replace_standalone_identifier(final, uinfo[1], "pc." + uinfo[1])
	# Replace gn_resolution with pc.gn_resolution
	final = _replace_standalone_identifier(final, "gn_resolution", "pc.gn_resolution")

	# Remove any #define lines we may have emitted
	var clean_lines: PackedStringArray = PackedStringArray()
	for fline in final.split("\n"):
		if not fline.strip_edges().begins_with("#define"):
			clean_lines.append(fline)

	return "\n".join(clean_lines)


static func _replace_standalone_identifier(text: String, word: String, replacement: String) -> String:
	var result := ""
	var i := 0
	var word_len := word.length()
	while i < text.length():
		var found := text.find(word, i)
		if found == -1:
			result += text.substr(i)
			break
		var before_ok := (found == 0) or not _is_ident_char(text[found - 1])
		var after_pos := found + word_len
		var after_ok := (after_pos >= text.length()) or not _is_ident_char(text[after_pos])
		var preceded_by_pc := found >= 3 and text.substr(found - 3, 3) == "pc."

		if before_ok and after_ok and not preceded_by_pc:
			result += text.substr(i, found - i) + replacement
		else:
			result += text.substr(i, found - i) + word
		i = found + word_len
	return result


static func _is_ident_char(c: String) -> bool:
	return c == "_" or c.is_valid_identifier() or c.is_valid_int()


static func _extract_tex_name(stripped: String) -> String:
	var pos := stripped.find("gn_tex")
	if pos == -1:
		return ""
	var end := pos + 6
	while end < stripped.length() and stripped[end].is_valid_int():
		end += 1
	return stripped.substr(pos, end - pos)


static func _extract_tex_index(name: String) -> int:
	var digits := name.substr(6)
	if digits.is_valid_int():
		return digits.to_int()
	return -1


static func _parse_uniform_for_transpile(stripped: String) -> Array:
	for type_kw in ["vec4", "vec2", "float", "int", "bool"]:
		if stripped.find(type_kw) != -1:
			var uname := CustomShaderTOP._extract_name_after(stripped, type_kw)
			if not uname.is_empty():
				return [type_kw, uname]
	return []


func _compile_mrt(code: String) -> void:
	_free_mrt_shader()

	var frag_code := _transpile_to_glsl450(code)

	var src := RDShaderSource.new()
	src.source_vertex = _VERT_GLSL
	src.source_fragment = frag_code
	var spirv := _rd.shader_compile_spirv_from_source(src)

	var vert_err: String = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_VERTEX)
	if not vert_err.is_empty():
		GNLogger.error("GLSLMultiTOP", "'%s' -- vertex compile error:\n%s" % [id, vert_err])
		_shader_ok = false
		return

	var frag_err: String = spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_FRAGMENT)
	if not frag_err.is_empty():
		GNLogger.error("GLSLMultiTOP", "'%s' -- fragment compile error:\n%s" % [id, frag_err])
		_shader_ok = false
		return

	_shader_rid = _rd.shader_create_from_spirv(spirv)
	if not _shader_rid.is_valid():
		GNLogger.error("GLSLMultiTOP", "'%s' -- failed to create shader from SPIR-V" % id)
		_shader_ok = false
		return

	_shader_ok = true
	GNLogger.info("GLSLMultiTOP",
		"'%s' -- MRT shader compiled (%d outputs, %d chars)" % [id, _output_count, code.length()])


func _ensure_mrt_framebuffer(size: Vector2i) -> void:
	if size == _last_mrt_size and _framebuffer_rid.is_valid():
		return

	_free_mrt_framebuffer()

	var tex_rids: Array[RID] = []
	for i in range(_output_count):
		var tf := RDTextureFormat.new()
		tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		tf.width = size.x
		tf.height = size.y
		tf.depth = 1
		tf.array_layers = 1
		tf.mipmaps = 1
		tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
		tf.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		)
		var rid := _rd.texture_create(tf, RDTextureView.new())
		tex_rids.append(rid)

	_output_tex_rids = tex_rids
	_framebuffer_rid = _rd.framebuffer_create(tex_rids)
	_last_mrt_size = size

	while _output_image_textures.size() < _output_count:
		_output_image_textures.append(null)
	while _output_image_textures.size() > _output_count:
		_output_image_textures.pop_back()

	while _output_textures.size() < _output_count:
		_output_textures.append(GNTextureData.new())
	while _output_textures.size() > _output_count:
		_output_textures.pop_back()

	if _pipeline_rid.is_valid():
		_rd.free_rid(_pipeline_rid)
		_pipeline_rid = RID()

	if _shader_rid.is_valid():
		var blend := RDPipelineColorBlendState.new()
		for i in range(_output_count):
			var att := RDPipelineColorBlendStateAttachment.new()
			blend.attachments.append(att)

		var raster := RDPipelineRasterizationState.new()
		var multisample := RDPipelineMultisampleState.new()
		var depth := RDPipelineDepthStencilState.new()

		_pipeline_rid = _rd.render_pipeline_create(
			_shader_rid,
			_rd.framebuffer_get_format(_framebuffer_rid),
			_rd.vertex_format_create([_make_vertex_attr()]),
			RenderingDevice.RENDER_PRIMITIVE_TRIANGLES,
			raster, multisample, depth, blend
		)


static func _make_vertex_attr() -> RDVertexAttribute:
	var vf := RDVertexAttribute.new()
	vf.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	vf.location = 0
	vf.stride = 8
	vf.offset = 0
	return vf


func _cook_mrt(inputs: Array[GNData], res: Vector2i) -> GNData:
	_ensure_mrt_framebuffer(res)
	if not _framebuffer_rid.is_valid() or not _pipeline_rid.is_valid():
		return null

	_update_mrt_input_textures(inputs)

	var push_bytes := _build_mrt_push_constants(res)

	var clear_colors: PackedColorArray = PackedColorArray()
	for i in range(_output_count):
		clear_colors.append(Color(0.0, 0.0, 0.0, 0.0))

	var draw_flags := RenderingDevice.DRAW_CLEAR_COLOR_ALL
	var dl := _rd.draw_list_begin(
		_framebuffer_rid,
		draw_flags,
		clear_colors
	)
	_rd.draw_list_bind_render_pipeline(dl, _pipeline_rid)
	_rd.draw_list_bind_vertex_array(dl, _vertex_array_rid)

	if _input_uniform_set.is_valid():
		_rd.draw_list_bind_uniform_set(dl, _input_uniform_set, 0)

	if push_bytes.size() > 0:
		_rd.draw_list_set_push_constant(dl, push_bytes, push_bytes.size())

	_rd.draw_list_draw(dl, false, 1)
	_rd.draw_list_end()
	_rd.submit()
	_rd.sync()

	for i in range(_output_count):
		var bytes := _rd.texture_get_data(_output_tex_rids[i], 0)
		var img := Image.create_from_data(res.x, res.y, false, Image.FORMAT_RGBA8, bytes)
		if _output_image_textures[i] == null:
			_output_image_textures[i] = ImageTexture.create_from_image(img)
		else:
			_output_image_textures[i].update(img)
		_output_textures[i].texture = _output_image_textures[i]
		_output_textures[i].resolution = res

	_cached_tex_data = _output_textures[0]
	return _cached_tex_data


func _build_mrt_push_constants(res: Vector2i) -> PackedByteArray:
	var user_count := _dynamic_param_names.size()
	var raw_fields := 4 + user_count
	var padded_size := ceili(float(raw_fields * 4) / 16.0) * 16
	var bytes := PackedByteArray()
	bytes.resize(padded_size)

	bytes.encode_float(0, float(res.x))
	bytes.encode_float(4, float(res.y))
	bytes.encode_float(8, elapsed_time)
	bytes.encode_float(12, 0.0)

	var offset := 16
	for p_name in _dynamic_param_names:
		var val = get_param_value(p_name)
		var param: GNParameter = parameters.get(p_name, null)
		if param != null and (param.value_type == GNParameter.ValueType.INT or param.value_type == GNParameter.ValueType.BOOL):
			bytes.encode_s32(offset, int(val))
		else:
			bytes.encode_float(offset, float(val))
		offset += 4

	return bytes


func _update_mrt_input_textures(inputs: Array[GNData]) -> void:
	var tex_count := input_ports.size()
	if tex_count == 0:
		return
	var needs_rebuild := _input_tex_rids.size() != tex_count
	if not needs_rebuild:
		for i in range(tex_count):
			var needed := _mrt_input_size(inputs, i)
			if i >= _input_tex_sizes.size() or _input_tex_sizes[i] != needed:
				needs_rebuild = true
				break
	if needs_rebuild:
		_free_mrt_input_textures()
		_create_mrt_input_textures(inputs)
	else:
		for i in range(tex_count):
			if i >= _input_tex_rids.size():
				break
			var img := _get_input_image(inputs, i)
			img.convert(Image.FORMAT_RGBA8)
			_rd.texture_update(_input_tex_rids[i], 0, img.get_data())


func _mrt_input_size(inputs: Array[GNData], slot: int) -> Vector2i:
	if slot < inputs.size() and inputs[slot] is GNTextureData:
		var td: GNTextureData = inputs[slot] as GNTextureData
		if td.texture != null:
			var img := td.texture.get_image()
			if img != null:
				return Vector2i(img.get_width(), img.get_height())
	return Vector2i(1, 1)


func _create_mrt_input_textures(inputs: Array[GNData]) -> void:
	var uniforms: Array[RDUniform] = []
	for i in range(input_ports.size()):
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
		var rid := _rd.texture_create(tf, RDTextureView.new(), [img.get_data()])
		_input_tex_rids.append(rid)
		_input_tex_sizes.append(Vector2i(img.get_width(), img.get_height()))
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = i
		u.add_id(_sampler_rid)
		u.add_id(rid)
		uniforms.append(u)
	if uniforms.size() > 0 and _shader_rid.is_valid():
		_input_uniform_set = _rd.uniform_set_create(uniforms, _shader_rid, 0)


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


func _free_mrt_shader() -> void:
	if _rd == null:
		return
	_free_mrt_framebuffer()
	if _pipeline_rid.is_valid():
		_rd.free_rid(_pipeline_rid)
		_pipeline_rid = RID()
	if _shader_rid.is_valid():
		_rd.free_rid(_shader_rid)
		_shader_rid = RID()


func _free_mrt_framebuffer() -> void:
	if _rd == null:
		return
	if _framebuffer_rid.is_valid():
		_rd.free_rid(_framebuffer_rid)
		_framebuffer_rid = RID()
	for rid in _output_tex_rids:
		if rid.is_valid():
			_rd.free_rid(rid)
	_output_tex_rids.clear()
	_last_mrt_size = Vector2i.ZERO
	if _pipeline_rid.is_valid():
		_rd.free_rid(_pipeline_rid)
		_pipeline_rid = RID()


func _free_mrt_input_textures() -> void:
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


func _cleanup_mrt() -> void:
	if _rd == null:
		return
	_free_mrt_input_textures()
	_free_mrt_framebuffer()
	_free_mrt_shader()
	if _vertex_array_rid.is_valid():
		_rd.free_rid(_vertex_array_rid)
	if _vertex_buffer_rid.is_valid():
		_rd.free_rid(_vertex_buffer_rid)
	if _sampler_rid.is_valid():
		_rd.free_rid(_sampler_rid)
	_rd.free()
	_rd = null


# ===========================================================================
# #### FALLBACK PATH (multi-pass SubViewport) ####
# ===========================================================================

func _ensure_fallback_viewports(count: int, size: Vector2i) -> void:
	while _fb_viewports.size() < count:
		var idx := _fb_viewports.size()
		var vp := SubViewport.new()
		vp.name = "FBPass%d" % idx
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.gui_disable_input = true
		add_child(vp)

		var shader := Shader.new()
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var canvas := ColorRect.new()
		canvas.name = "Canvas"
		canvas.material = mat
		vp.add_child(canvas)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		_fb_shaders.append(shader)
		_fb_viewports.append(vp)
		_fb_materials.append(mat)
		_fb_canvases.append(canvas)
		_output_textures.append(GNTextureData.new())

	while _fb_viewports.size() > count:
		var idx := _fb_viewports.size() - 1
		_fb_viewports[idx].queue_free()
		_fb_viewports.remove_at(idx)
		_fb_shaders.remove_at(idx)
		_fb_materials.remove_at(idx)
		_fb_canvases.remove_at(idx)
		if _output_textures.size() > count:
			_output_textures.remove_at(_output_textures.size() - 1)


func _compile_fallback(code: String) -> void:
	_ensure_fallback_viewports(_output_count, Vector2i(512, 512))
	for i in range(_output_count):
		var variant := _generate_fallback_variant(code, i)
		_fb_shaders[i].code = variant
		_fb_materials[i].shader = _fb_shaders[i]
	_shader_ok = true


func _generate_fallback_variant(code: String, out_idx: int) -> String:
	var frag_pos := code.find("void fragment()")
	if frag_pos == -1:
		frag_pos = code.find("void fragment ()")
	if frag_pos == -1:
		return code
	var brace_pos := code.find("{", frag_pos)
	if brace_pos == -1:
		return code
	var declarations := ""
	for i in range(_output_count):
		declarations += "\n\tvec4 gn_out%d = vec4(0.0);" % i
	var close_brace := _find_matching_brace(code, brace_pos)
	if close_brace == -1:
		return code
	var before := code.substr(0, brace_pos + 1)
	var body := code.substr(brace_pos + 1, close_brace - brace_pos - 1)
	var after := code.substr(close_brace)
	return before + declarations + body + "\n\tCOLOR = gn_out%d;\n" % out_idx + after


static func _find_matching_brace(code: String, open_pos: int) -> int:
	var depth := 0
	for i in range(open_pos, code.length()):
		if code[i] == "{":
			depth += 1
		elif code[i] == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1


func _cook_fallback(inputs: Array[GNData], res: Vector2i) -> GNData:
	_ensure_fallback_viewports(_output_count, res)

	for idx in range(_output_count):
		var vp := _fb_viewports[idx]
		if vp.size != res:
			vp.size = res
		var mat := _fb_materials[idx]
		for i in range(input_ports.size()):
			var tex: GNTextureData = inputs[i] as GNTextureData if i < inputs.size() and inputs[i] is GNTextureData else null
			if tex != null:
				mat.set_shader_parameter("gn_tex%d" % i, tex.texture)
		for p_name in _dynamic_param_names:
			mat.set_shader_parameter(p_name, get_param_value(p_name))
		mat.set_shader_parameter("gn_resolution", Vector2(res))

		_output_textures[idx].texture = vp.get_texture()
		_output_textures[idx].resolution = res

	_cached_tex_data = _output_textures[0]
	return _cached_tex_data


# ===========================================================================
# Shared Compilation
# ===========================================================================

func _compile_all(code: String) -> void:
	if code.is_empty():
		GNLogger.warn("GLSLMultiTOP", "'%s' -- empty shader code" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	if not code.strip_edges().begins_with("shader_type"):
		GNLogger.error("GLSLMultiTOP",
			"'%s' -- shader must begin with 'shader_type canvas_item;'" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	_rebuild_output_ports()

	if _use_mrt:
		_compile_mrt(code)
	else:
		_compile_fallback(code)

	_last_compiled_code = code

	var tex_count := CustomShaderTOP._count_shader_tex_inputs(code)
	if tex_count != input_ports.size():
		_rebuild_tex_inputs(tex_count)

	var is_generator := tex_count == 0
	var has_res_param := parameters.has("resolution")
	if is_generator and not has_res_param:
		var res_param := GNParameter.create_vector2i("resolution", Vector2i(512, 512),
			"", "Output texture resolution")
		var saved_params: Dictionary = {}
		for k in parameters:
			saved_params[k] = parameters[k]
		parameters.clear()
		parameters["resolution"] = res_param
		for k in saved_params:
			parameters[k] = saved_params[k]
		res_param.value_changed.connect(_on_parameter_changed)
		res_param.mode_changed.connect(_on_parameter_mode_changed)
	elif not is_generator and has_res_param:
		var res_param: GNParameter = parameters["resolution"]
		if res_param.value_changed.is_connected(_on_parameter_changed):
			res_param.value_changed.disconnect(_on_parameter_changed)
		if res_param.mode_changed.is_connected(_on_parameter_mode_changed):
			res_param.mode_changed.disconnect(_on_parameter_mode_changed)
		parameters.erase("resolution")

	_rebuild_uniform_params(code)


func _rebuild_output_ports() -> void:
	output_ports.clear()
	for i in range(_output_count):
		add_output("out%d" % i, GNFamily.Type.TOP, "Output %d (gn_out%d)" % [i, i])
	ports_changed.emit(id)


func _rebuild_tex_inputs(count: int) -> void:
	input_ports.clear()
	for i in range(count):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Texture input %d (gn_tex%d)" % [i, i], "Input %d" % i)
	GNLogger.info("GLSLMultiTOP", "'%s' input ports -> %d" % [id, count])
	ports_changed.emit(id)


func _rebuild_uniform_params(code: String) -> void:
	var new_uniforms: Array = CustomShaderTOP._parse_uniforms(code)
	var old_values: Dictionary = {}
	for p_name in _dynamic_param_names:
		var param := get_parameter(p_name)
		if param != null:
			old_values[p_name] = { "value": param.value, "type": param.value_type }
	for p_name in _dynamic_param_names:
		if parameters.has(p_name):
			var param: GNParameter = parameters[p_name]
			if param.value_changed.is_connected(_on_parameter_changed):
				param.value_changed.disconnect(_on_parameter_changed)
			if param.mode_changed.is_connected(_on_parameter_mode_changed):
				param.mode_changed.disconnect(_on_parameter_mode_changed)
			parameters.erase(p_name)
	_dynamic_param_names.clear()

	for info in new_uniforms:
		var ui: CustomShaderTOP._UniformInfo = info as CustomShaderTOP._UniformInfo
		if ui.uniform_name in _RESERVED_UNIFORMS:
			continue
		var param: GNParameter = null
		match ui.type:
			GNParameter.ValueType.FLOAT:
				param = GNParameter.create_float(ui.uniform_name, ui.default_value,
					null, null, 0.01, "", "Shader uniform '%s'" % ui.uniform_name)
			GNParameter.ValueType.INT:
				param = GNParameter.create_int(ui.uniform_name, ui.default_value,
					null, null, "", "Shader uniform '%s'" % ui.uniform_name)
			GNParameter.ValueType.BOOL:
				param = GNParameter.create_bool(ui.uniform_name, ui.default_value,
					"", "Shader uniform '%s'" % ui.uniform_name)
			GNParameter.ValueType.VECTOR2:
				param = GNParameter.create_vector2(ui.uniform_name, ui.default_value,
					"", "Shader uniform '%s'" % ui.uniform_name)
			GNParameter.ValueType.COLOR:
				param = GNParameter.create_color(ui.uniform_name, ui.default_value,
					"", "Shader uniform '%s'" % ui.uniform_name)
		if param == null:
			continue
		if old_values.has(ui.uniform_name):
			var old: Dictionary = old_values[ui.uniform_name]
			if old["type"] == ui.type:
				param.value = old["value"]
				param.resolved_value = old["value"]
		add_parameter(param)
		param.value_changed.connect(_on_parameter_changed)
		param.mode_changed.connect(_on_parameter_mode_changed)
		_dynamic_param_names.append(ui.uniform_name)

	GNLogger.info("GLSLMultiTOP", "'%s' dynamic params -> %s" % [id, str(_dynamic_param_names)])
	parameters_changed.emit(id)
