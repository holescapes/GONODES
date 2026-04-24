class_name CustomShaderTOP
extends GNTopBase
## Allows the user to write custom Godot Shading Language (GLSL-like) code
## that runs on the GPU.  Input texture ports AND inspector parameters are
## created **dynamically** by scanning the shader source for uniform declarations.
##
## The user provides the FULL shader source (shader_type canvas_item; …).
## A default template is loaded on first cook if no code is set.
## The shader is recompiled only when the code text changes.
##
## How uniforms map to the editor:
##   uniform sampler2D gn_tex<N>;       → Auto-creates input port N (up to 8)
##   uniform float     <name> = …;     → Creates a Float parameter named <name>
##   uniform int       <name> = …;     → Creates an Int parameter named <name>
##   uniform bool      <name> = …;     → Creates a Bool parameter named <name>
##   uniform vec2      <name> = …;     → Creates a Vector2 parameter named <name>
##   uniform vec4      <name> : source_color = …; → Creates a Color parameter
##   uniform vec4      <name> = …;     → Creates a Color parameter named <name>
##   uniform vec2      gn_resolution;  → Auto-bound to output resolution (no param)
##   uniform float     gn_time;       → Auto-bound to elapsed time in seconds (no param)
##   uniform int       gn_frame;      → Auto-bound to current frame number (no param)
##   uniform float     gn_dt;         → Auto-bound to delta time this frame (no param)
##   TIME                               → Built-in to Godot shaders (no uniform)
##
## Fragment-only snippets (no shader_type) are auto-wrapped with a preamble.
## Commented-out uniforms ("// uniform ...") are uncommented and registered.
##
## Reserved uniform names (no param created):
##   gn_tex0..gn_tex7   — handled as input texture ports
##   gn_resolution      — auto-bound to output resolution
##   gn_time            — auto-bound to elapsed time
##   gn_frame           — auto-bound to frame count
##   gn_dt              — auto-bound to delta time

const DEFAULT_SHADER_CODE := """shader_type canvas_item;

// ─── GONODES Uniforms (auto-bound) ───────────────────────
// Input textures — add more gn_tex<N> uniforms to auto-create input ports.
uniform sampler2D gn_tex0 : hint_default_white;

// Auto-bound timing uniforms (values injected by the cook engine):
uniform float gn_time;   // Elapsed time in seconds
// uniform int gn_frame;  // Current frame number
// uniform float gn_dt;   // Delta time this frame

// Your own uniforms — each becomes an inspector parameter automatically.
// Supported types: float, int, bool, vec2, vec4 (color).
// uniform float brightness = 1.0;
// uniform vec4 tint : source_color = vec4(1.0);

// gn_resolution is auto-bound (no param created).
// uniform vec2 gn_resolution;

// ─── Your fragment shader ────────────────────────────────
void fragment() {
	vec4 src = texture(gn_tex0, UV);
	COLOR = src;
}
"""

## Uniform names that are auto-bound and should NOT create inspector params.
## (gn_tex* are already excluded by the sampler2D filter.)
const _RESERVED_UNIFORMS: Array = ["gn_resolution", "gn_time", "gn_frame", "gn_dt"]

var _shader: Shader = null

## Track the last successfully compiled code to avoid redundant recompiles.
var _last_compiled_code: String = ""

## Whether the current shader compiled successfully.
var _shader_ok: bool = false

## Names of parameters dynamically created from shader uniform declarations.
## Rebuilt each time the shader code changes.  Used in _cook() to bind values.
var _dynamic_param_names: PackedStringArray = PackedStringArray()


func _init() -> void:
	node_type = "custom_shader"
	time_dependent = true  # Default on — user can toggle off via parameter


func _init_ports() -> void:
	# Default shader uses gn_tex0 only — ports are rebuilt when shader code changes
	add_input("in0", GNFamily.Type.TOP, false, "Texture input 0 (gn_tex0 in shader)", "Input 0")
	add_output("out", GNFamily.Type.TOP, "Shader output texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (enable for shaders using TIME)"))
	add_parameter(GNParameter.create_bool("cook_once", false,
		"Cook Once", "Pulse: toggle ON to force a single cook, auto-resets to OFF"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Resolution", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_string("shader_code", DEFAULT_SHADER_CODE.strip_edges(),
		"Shader Code", "Full shader_type canvas_item shader code (live recompile)"))


## Override _pre_cook to respect the time_dependent parameter toggle.
func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	# Cook-once pulse: mark dirty for one frame, then auto-reset
	if get_param_value("cook_once"):
		mark_dirty()
		set_param_value("cook_once", false)
	super._pre_cook(delta)


## Override from_dict to rebuild dynamic params from the restored shader code
## BEFORE trying to restore the dynamic param values from the save file.
func from_dict(d: Dictionary) -> void:
	# Restore static params first (shader_code, resolution, position, etc.)
	super.from_dict(d)

	# Now the shader_code param has the saved value — parse it to create dynamic params
	var code: String = get_param_value("shader_code")
	if not code.is_empty():
		var init_size := Vector2i(512, 512)
		if parameters.has("resolution"):
			init_size = get_param_value("resolution")
		_setup_viewport(init_size)
		_compile_shader(code)

	# Now dynamic params exist — restore their saved values
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for param_name in params_dict:
			# Skip static params (already restored by super)
			if param_name in ["resolution", "shader_code", "time_dependent", "cook_once"]:
				continue
			var param: GNParameter = parameters.get(param_name, null)
			if param != null:
				param.from_dict(params_dict[param_name])


func _cook(inputs: Array[GNData]) -> GNData:
	# ── Resolution (computed first so viewport is created at correct size) ──
	var res := Vector2i(512, 512)

	# Generator shaders have a resolution param; filter shaders inherit from input
	if parameters.has("resolution"):
		res = get_param_value("resolution")

	# If an input is connected, use its resolution
	var tex0: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex0 != null:
		res = tex0.resolution

	_setup_viewport(res)

	# ── Compile shader if code changed ──
	var code: String = get_param_value("shader_code")
	if code != _last_compiled_code:
		_compile_shader(code)

	if not _shader_ok:
		# Return last good output (or null on first failure)
		return _cached_tex_data if _cached_tex_data != null else null

	if _viewport.size != res:
		_viewport.size = res

	# ── Bind input textures (dynamic count from shader parsing) ──
	for i in range(input_ports.size()):
		var tex: GNTextureData = inputs[i] as GNTextureData if i < inputs.size() and inputs[i] is GNTextureData else null
		if tex != null:
			_material.set_shader_parameter("gn_tex%d" % i, tex.texture)

	# ── Bind all dynamic uniform params (name == shader uniform name) ──
	for p_name in _dynamic_param_names:
		_material.set_shader_parameter(p_name, get_param_value(p_name))

	# ── Auto-bound reserved uniforms ──
	_material.set_shader_parameter("gn_resolution", Vector2(res))
	_material.set_shader_parameter("gn_time", elapsed_time)
	_material.set_shader_parameter("gn_frame", current_frame)
	_material.set_shader_parameter("gn_dt", current_delta)

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Attempts to compile the shader from source code.
## On failure, keeps the old shader active and logs the error.
## On success, scans for uniforms and rebuilds input ports + params to match.
func _compile_shader(code: String) -> void:
	if code.is_empty():
		GNLogger.warn("CustomShaderTOP", "'%s' — empty shader code" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	# ── Auto-wrap snippet code ──
	# If the code doesn't start with 'shader_type', treat it as a fragment
	# snippet and wrap it with the full preamble.  This supports the preset
	# convention where files contain only commented uniforms + fragment().
	var compile_code := code
	if not code.strip_edges().begins_with("shader_type"):
		compile_code = _wrap_snippet(code)

	# Validate basic structure
	if not compile_code.strip_edges().begins_with("shader_type"):
		GNLogger.error("CustomShaderTOP",
			"'%s' — shader must begin with 'shader_type canvas_item;'" % id)
		_shader_ok = false
		_last_compiled_code = code
		return

	# Attempt compilation by setting the code on the Shader resource.
	var new_shader := Shader.new()
	new_shader.code = compile_code

	_shader = new_shader
	_material.shader = _shader
	_shader_ok = true
	_last_compiled_code = code
	GNLogger.info("CustomShaderTOP", "'%s' — shader compiled (%d chars)" % [id, compile_code.length()])

	# Rebuild input ports to match the sampler2D gn_tex<N> uniforms found in code
	var tex_count := _count_shader_tex_inputs(compile_code)
	if tex_count != input_ports.size():
		_rebuild_tex_inputs(tex_count)

	# Resolution param: only needed for generator shaders (no texture inputs).
	# Filter shaders auto-inherit resolution from their input.
	var is_generator := tex_count == 0
	var has_res_param := parameters.has("resolution")
	if is_generator and not has_res_param:
		var res_param := GNParameter.create_vector2i("resolution", Vector2i(512, 512), "Resolution", "Output texture resolution in pixels")
		# Insert resolution before shader_code by removing/re-adding
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

	# Rebuild dynamic params from non-reserved uniforms
	_rebuild_uniform_params(compile_code)


# ═══════════════════════════════════════════════════════════════════════════════
# Snippet Auto-Wrapping
# ═══════════════════════════════════════════════════════════════════════════════

## Wraps a fragment-only snippet into a full shader_type canvas_item shader.
## Scans the snippet for:
##   • gn_tex<N> references → generates sampler2D uniform declarations
##   • Commented-out uniforms ("// uniform ...") → uncomments them as real uniforms
##   • gn_time / gn_frame / gn_dt / gn_resolution references → adds uniform decls
## Returns a complete shader string ready for Shader.code.
static func _wrap_snippet(snippet: String) -> String:
	var lines := snippet.split("\n")
	var preamble_lines: PackedStringArray = PackedStringArray()
	preamble_lines.append("shader_type canvas_item;")
	preamble_lines.append("")

	# Collect gn_tex references
	var max_tex_idx := -1
	for line in lines:
		var pos := 0
		while true:
			var found := line.find("gn_tex", pos)
			if found == -1:
				break
			var digit_start := found + 6
			var digit_str := ""
			while digit_start < line.length() and line[digit_start].is_valid_int():
				digit_str += line[digit_start]
				digit_start += 1
			if not digit_str.is_empty():
				var idx := digit_str.to_int()
				if idx > max_tex_idx:
					max_tex_idx = idx
			pos = found + 1

	for i in range(max_tex_idx + 1):
		preamble_lines.append("uniform sampler2D gn_tex%d : hint_default_white;" % i)

	# Auto-bind reserved uniforms if referenced
	if snippet.find("gn_resolution") != -1:
		preamble_lines.append("uniform vec2 gn_resolution;")
	if snippet.find("gn_time") != -1:
		preamble_lines.append("uniform float gn_time;")
	if snippet.find("gn_frame") != -1:
		preamble_lines.append("uniform int gn_frame;")
	if snippet.find("gn_dt") != -1:
		preamble_lines.append("uniform float gn_dt;")

	# Extract commented-out uniforms and emit them as real declarations
	var body_lines: PackedStringArray = PackedStringArray()
	for line in lines:
		var stripped := line.strip_edges()
		if stripped.begins_with("// uniform ") or stripped.begins_with("//uniform "):
			# Uncomment: strip leading "// " or "//"
			var real_line := stripped.substr(2).strip_edges()
			# Ensure it ends with semicolon
			if not real_line.ends_with(";"):
				real_line += ";"
			preamble_lines.append(real_line)
		else:
			body_lines.append(line)

	preamble_lines.append("")
	return "\n".join(preamble_lines) + "\n" + "\n".join(body_lines)


# ═══════════════════════════════════════════════════════════════════════════════
# Uniform Parsing & Dynamic Parameters
# ═══════════════════════════════════════════════════════════════════════════════

## Parses shader source for `uniform sampler2D gn_tex<N>` declarations and
## returns how many distinct texture input slots the shader expects (clamped 0-8).
## Uses simple line-by-line scanning — no regex dependency.
static func _count_shader_tex_inputs(code: String) -> int:
	var max_idx: int = -1
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("//"):
			continue
		var pos := stripped.find("uniform")
		if pos == -1:
			continue
		var sampler_pos := stripped.find("sampler2D", pos)
		if sampler_pos == -1:
			continue
		var tex_pos := stripped.find("gn_tex", sampler_pos)
		if tex_pos == -1:
			continue
		var digit_start := tex_pos + 6  # len("gn_tex")
		var digit_str := ""
		while digit_start < stripped.length() and stripped[digit_start].is_valid_int():
			digit_str += stripped[digit_start]
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
	GNLogger.info("CustomShaderTOP", "'%s' input ports → %d (from shader uniforms)" % [id, count])
	ports_changed.emit(id)


## Information about one parsed uniform declaration.
class _UniformInfo:
	var uniform_name: String
	var type: GNParameter.ValueType
	var default_value: Variant

	func _init(p_name: String, p_type: GNParameter.ValueType, p_default: Variant) -> void:
		uniform_name = p_name
		type = p_type
		default_value = p_default


## Parses ALL non-reserved, non-sampler uniforms from the shader code.
## Returns an Array of _UniformInfo in declaration order.
static func _parse_uniforms(code: String) -> Array:
	var result: Array = []
	for line in code.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("//"):
			continue
		if stripped.find("uniform") == -1:
			continue
		# Skip sampler2D (handled as texture ports)
		if stripped.find("sampler2D") != -1:
			continue

		# Determine type
		var info: _UniformInfo = null
		if stripped.find("vec4") != -1:
			info = _parse_vec4_uniform(stripped)
		elif stripped.find("vec2") != -1:
			info = _parse_vec2_uniform(stripped)
		elif stripped.find("float") != -1:
			info = _parse_float_uniform(stripped)
		elif stripped.find("int") != -1:
			info = _parse_int_uniform(stripped)
		elif stripped.find("bool") != -1:
			info = _parse_bool_uniform(stripped)

		if info != null and info.uniform_name not in _RESERVED_UNIFORMS:
			result.append(info)
	return result


## Extracts the uniform name from a stripped line.
## Expects the name to be the token right after the type keyword.
## e.g. "uniform float brightness = 0.5;" → "brightness"
static func _extract_name_after(stripped: String, type_keyword: String) -> String:
	var type_pos := stripped.find(type_keyword)
	if type_pos == -1:
		return ""
	var start := type_pos + type_keyword.length()
	# Skip whitespace
	while start < stripped.length() and stripped[start] == " ":
		start += 1
	# Read identifier characters (alphanumeric + underscore)
	var name_str := ""
	while start < stripped.length():
		var c := stripped[start]
		if c == "_" or c.is_valid_identifier():
			name_str += c
			start += 1
		else:
			break
	return name_str


static func _parse_float_uniform(stripped: String) -> _UniformInfo:
	var uname := _extract_name_after(stripped, "float")
	if uname.is_empty():
		return null
	var def_val := 0.0
	var eq_pos := stripped.find("=")
	if eq_pos != -1:
		var val_str := stripped.substr(eq_pos + 1).strip_edges().rstrip(";").strip_edges()
		if val_str.is_valid_float():
			def_val = val_str.to_float()
	return _UniformInfo.new(uname, GNParameter.ValueType.FLOAT, def_val)


static func _parse_int_uniform(stripped: String) -> _UniformInfo:
	var uname := _extract_name_after(stripped, "int")
	if uname.is_empty():
		return null
	var def_val := 0
	var eq_pos := stripped.find("=")
	if eq_pos != -1:
		var val_str := stripped.substr(eq_pos + 1).strip_edges().rstrip(";").strip_edges()
		if val_str.is_valid_int():
			def_val = val_str.to_int()
	return _UniformInfo.new(uname, GNParameter.ValueType.INT, def_val)


static func _parse_bool_uniform(stripped: String) -> _UniformInfo:
	var uname := _extract_name_after(stripped, "bool")
	if uname.is_empty():
		return null
	var def_val := false
	var eq_pos := stripped.find("=")
	if eq_pos != -1:
		var val_str := stripped.substr(eq_pos + 1).strip_edges().rstrip(";").strip_edges()
		def_val = val_str == "true"
	return _UniformInfo.new(uname, GNParameter.ValueType.BOOL, def_val)


static func _parse_vec2_uniform(stripped: String) -> _UniformInfo:
	var uname := _extract_name_after(stripped, "vec2")
	if uname.is_empty():
		return null
	var def_val := Vector2.ZERO
	var eq_pos := stripped.find("=")
	if eq_pos != -1:
		# Try to extract vec2(x, y) or vec2(x)
		var vec_pos := stripped.find("vec2(", eq_pos)
		if vec_pos != -1:
			var inner := _extract_parens(stripped, vec_pos + 4)
			var parts := inner.split(",")
			if parts.size() >= 2:
				def_val = Vector2(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float())
			elif parts.size() == 1 and not parts[0].strip_edges().is_empty():
				var v := parts[0].strip_edges().to_float()
				def_val = Vector2(v, v)
	return _UniformInfo.new(uname, GNParameter.ValueType.VECTOR2, def_val)


static func _parse_vec4_uniform(stripped: String) -> _UniformInfo:
	var uname := _extract_name_after(stripped, "vec4")
	if uname.is_empty():
		return null
	var def_val := Color.WHITE
	var eq_pos := stripped.find("=")
	if eq_pos != -1:
		var vec_pos := stripped.find("vec4(", eq_pos)
		if vec_pos != -1:
			var inner := _extract_parens(stripped, vec_pos + 4)
			var parts := inner.split(",")
			if parts.size() >= 4:
				def_val = Color(
					parts[0].strip_edges().to_float(),
					parts[1].strip_edges().to_float(),
					parts[2].strip_edges().to_float(),
					parts[3].strip_edges().to_float())
			elif parts.size() == 1 and not parts[0].strip_edges().is_empty():
				var v := parts[0].strip_edges().to_float()
				def_val = Color(v, v, v, v)
	return _UniformInfo.new(uname, GNParameter.ValueType.COLOR, def_val)


## Extracts text between '(' at [param open_pos] and matching ')'.
static func _extract_parens(text: String, open_pos: int) -> String:
	var depth := 0
	var start := open_pos + 1
	for i in range(open_pos, text.length()):
		if text[i] == "(":
			depth += 1
		elif text[i] == ")":
			depth -= 1
			if depth == 0:
				return text.substr(start, i - start)
	return text.substr(start)


## Removes old dynamic params, creates new ones from shader uniforms,
## preserving any values that match by name + type.
func _rebuild_uniform_params(code: String) -> void:
	var new_uniforms: Array = _parse_uniforms(code)

	# Snapshot old dynamic param values for preservation
	var old_values: Dictionary = {}  # name → { "value": Variant, "type": ValueType }
	for p_name in _dynamic_param_names:
		var param := get_parameter(p_name)
		if param != null:
			old_values[p_name] = { "value": param.value, "type": param.value_type }

	# Remove old dynamic params
	for p_name in _dynamic_param_names:
		if parameters.has(p_name):
			var param: GNParameter = parameters[p_name]
			# Disconnect signals
			if param.value_changed.is_connected(_on_parameter_changed):
				param.value_changed.disconnect(_on_parameter_changed)
			if param.mode_changed.is_connected(_on_parameter_mode_changed):
				param.mode_changed.disconnect(_on_parameter_mode_changed)
			parameters.erase(p_name)
	_dynamic_param_names.clear()

	# Create new params from parsed uniforms
	for info in new_uniforms:
		var ui: _UniformInfo = info as _UniformInfo
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

		# Restore previous value if same name and type existed before
		if old_values.has(ui.uniform_name):
			var old: Dictionary = old_values[ui.uniform_name]
			if old["type"] == ui.type:
				param.value = old["value"]
				param.resolved_value = old["value"]

		# Register and wire signals
		add_parameter(param)
		_dynamic_param_names.append(ui.uniform_name)

	GNLogger.info("CustomShaderTOP", "'%s' dynamic params → %s" % [id, str(_dynamic_param_names)])
	parameters_changed.emit(id)


func _setup_viewport(size: Vector2i = Vector2i(512, 512)) -> void:
	if _viewport != null:
		return

	_shader = Shader.new()
	_shader.code = DEFAULT_SHADER_CODE

	_ensure_viewport(size)

	_material = ShaderMaterial.new()
	_material.shader = _shader

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_shader_ok = true
	_last_compiled_code = DEFAULT_SHADER_CODE
