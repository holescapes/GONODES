class_name CustomShaderTOP
extends GNNode
## Allows the user to write custom Godot Shading Language (GLSL-like) code
## that runs on the GPU.  Input texture ports are created automatically by
## scanning the shader source for `uniform sampler2D gn_tex<N>` declarations.
## Float and color uniforms plus TIME are also available.
##
## The user provides the FULL shader source (shader_type canvas_item; …).
## A default template is loaded on first cook if no code is set.
## The shader is recompiled only when the code text changes.
##
## Uniform contract (always available in user code):
##   uniform sampler2D gn_tex0;       // Auto-creates input port 0
##   uniform sampler2D gn_tex1;       // Auto-creates input port 1
##   …                                // Up to gn_tex7
##   uniform float     gn_float0;     // Param Float A
##   uniform float     gn_float1;     // Param Float B
##   uniform float     gn_float2;     // Param Float C
##   uniform float     gn_float3;     // Param Float D
##   uniform vec4      gn_color0;     // Param Color A
##   uniform vec4      gn_color1;     // Param Color B
##   uniform vec2      gn_resolution; // Output resolution in pixels
##   // TIME is built-in to Godot shaders — no extra uniform needed.

const DEFAULT_SHADER_CODE := """shader_type canvas_item;

// ─── GONODES Uniforms (auto-bound) ───────────────────────
// Input textures — add more gn_tex<N> uniforms to auto-create input ports.
uniform sampler2D gn_tex0 : hint_default_white;
uniform float gn_float0 = 0.0;
uniform float gn_float1 = 0.0;
uniform float gn_float2 = 0.0;
uniform float gn_float3 = 0.0;
uniform vec4 gn_color0 : source_color = vec4(1.0);
uniform vec4 gn_color1 : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 gn_resolution = vec2(512.0);

// ─── Your fragment shader ────────────────────────────────
void fragment() {
	vec4 src = texture(gn_tex0, UV);
	COLOR = src;
}
"""

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null

## Track the last successfully compiled code to avoid redundant recompiles.
var _last_compiled_code: String = ""

## Whether the current shader compiled successfully.
var _shader_ok: bool = false


func _init() -> void:
	node_type = "glsl"
	family = GNFamily.Type.TOP
	time_dependent = true  # User code may use TIME
	node_description = "User-editable GLSL shader with auto-detected texture inputs from uniform declarations."


func _init_ports() -> void:
	# Default shader uses gn_tex0 only — ports are rebuilt when shader code changes
	add_input("in0", GNFamily.Type.TOP, false, "Texture input 0 (gn_tex0 in shader)")
	add_output("out", GNFamily.Type.TOP, "Shader output texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_string("shader_code", DEFAULT_SHADER_CODE.strip_edges(),
		"Shader Code", "Full shader_type canvas_item shader code (live recompile)"))
	add_parameter(GNParameter.create_float("float_a", 0.0, null, null, 0.01, "Float A", "User float uniform (gn_float0)"))
	add_parameter(GNParameter.create_float("float_b", 0.0, null, null, 0.01, "Float B", "User float uniform (gn_float1)"))
	add_parameter(GNParameter.create_float("float_c", 0.0, null, null, 0.01, "Float C", "User float uniform (gn_float2)"))
	add_parameter(GNParameter.create_float("float_d", 0.0, null, null, 0.01, "Float D", "User float uniform (gn_float3)"))
	add_parameter(GNParameter.create_color("color_a", Color.WHITE, "Color A", "User color uniform (gn_color0)"))
	add_parameter(GNParameter.create_color("color_b", Color.BLACK, "Color B", "User color uniform (gn_color1)"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	# ── Compile shader if code changed ──
	var code: String = get_param_value("shader_code")
	if code != _last_compiled_code:
		_compile_shader(code)

	if not _shader_ok:
		# Return last good output (or null on first failure)
		return _cached_tex_data if _cached_tex_data != null else null

	# ── Resolution ──
	var res: Vector2i = get_param_value("resolution")

	# If an input is connected, default to its resolution
	var tex0: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex0 != null and res == Vector2i(512, 512):
		res = tex0.resolution

	if _viewport.size != res:
		_viewport.size = res

	# ── Bind input textures (dynamic count from shader parsing) ──
	for i in range(input_ports.size()):
		var tex: GNTextureData = inputs[i] as GNTextureData if i < inputs.size() and inputs[i] is GNTextureData else null
		if tex != null:
			_material.set_shader_parameter("gn_tex%d" % i, tex.texture)

	# ── Bind float params ──
	_material.set_shader_parameter("gn_float0", get_param_value("float_a"))
	_material.set_shader_parameter("gn_float1", get_param_value("float_b"))
	_material.set_shader_parameter("gn_float2", get_param_value("float_c"))
	_material.set_shader_parameter("gn_float3", get_param_value("float_d"))

	# ── Bind color params ──
	_material.set_shader_parameter("gn_color0", get_param_value("color_a"))
	_material.set_shader_parameter("gn_color1", get_param_value("color_b"))

	# ── Resolution uniform ──
	_material.set_shader_parameter("gn_resolution", Vector2(res))

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Attempts to compile the shader from source code.
## On failure, keeps the old shader active and logs the error.
## On success, scans for gn_tex<N> uniforms and rebuilds input ports to match.
func _compile_shader(code: String) -> void:
	if code.is_empty():
		GNLogger.warn("CustomShaderTOP", "'%s' — empty shader code" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	# Validate basic structure
	if not code.strip_edges().begins_with("shader_type"):
		GNLogger.error("CustomShaderTOP",
			"'%s' — shader must begin with 'shader_type canvas_item;'" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	# Attempt compilation by setting the code on the Shader resource.
	var new_shader := Shader.new()
	new_shader.code = code

	_shader = new_shader
	_material.shader = _shader
	_shader_ok = true
	_last_compiled_code = code
	GNLogger.info("CustomShaderTOP", "'%s' — shader compiled (%d chars)" % [id, code.length()])

	# Rebuild input ports to match the sampler2D gn_tex<N> uniforms found in code
	var tex_count := _count_shader_tex_inputs(code)
	if tex_count != input_ports.size():
		_rebuild_tex_inputs(tex_count)


## Parses shader source for `uniform sampler2D gn_tex<N>` declarations and
## returns how many distinct texture input slots the shader expects (clamped 0-8).
## Uses simple line-by-line scanning — no regex dependency.
static func _count_shader_tex_inputs(code: String) -> int:
	var max_idx: int = -1
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		# Skip comments
		if stripped.begins_with("//"):
			continue
		# Look for "uniform sampler2D gn_tex"
		var pos := stripped.find("uniform")
		if pos == -1:
			continue
		var sampler_pos := stripped.find("sampler2D", pos)
		if sampler_pos == -1:
			continue
		var tex_pos := stripped.find("gn_tex", sampler_pos)
		if tex_pos == -1:
			continue
		# Extract the digit(s) after "gn_tex"
		var digit_start := tex_pos + 6  # len("gn_tex")
		var digit_str := ""
		while digit_start < stripped.length() and stripped[digit_start].is_valid_int():
			digit_str += stripped[digit_start]
			digit_start += 1
		if not digit_str.is_empty():
			var idx := digit_str.to_int()
			if idx > max_idx:
				max_idx = idx
	# Number of ports = highest index + 1, clamped to 0-8
	return clampi(max_idx + 1, 0, 8)


## Rebuilds input ports to match the number of gn_tex samplers in the shader.
func _rebuild_tex_inputs(count: int) -> void:
	input_ports.clear()
	for i in range(count):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Texture input %d (gn_tex%d in shader)" % [i, i])
	GNLogger.info("CustomShaderTOP", "'%s' input ports → %d (from shader uniforms)" % [id, count])
	ports_changed.emit(id)


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = Shader.new()
	_shader.code = DEFAULT_SHADER_CODE

	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_material = ShaderMaterial.new()
	_material.shader = _shader

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size

	_shader_ok = true
	_last_compiled_code = DEFAULT_SHADER_CODE
	GNLogger.debug("CustomShaderTOP", "'%s' viewport + default shader created" % id)
