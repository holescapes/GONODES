class_name ShadertoyURLTOP
extends GNTopBase
## Runtime Shadertoy-to-Godot shader translator and compiler.
##
## Accepts either:
##   1. **Pasted Shadertoy GLSL** in the [code]shadertoy_code[/code] parameter.
##   2. **A Shadertoy URL / ID** in the [code]shadertoy_url[/code] parameter,
##      combined with the [code]fetch[/code] pulse to download the shader from
##      the Shadertoy public API.
##
## The pasted code is run through [ShadertoyTranslator] to produce a Godot
## `shader_type canvas_item;` shader, which is then compiled and its uniforms
## scanned exactly like [CustomShaderTOP].
##
## ── Workflow ─────────────────────────────────────────────────────────────────
##   • Paste code ➜ auto-translate & compile on next cook.
##   • Enter URL  ➜ click Fetch ➜ API downloads code ➜ fills shadertoy_code.
##
## ── Multi-pass (future) ──────────────────────────────────────────────────────
## Only the main "Image" pass is converted.  Multi-pass (Buffer A-D) support
## would require creating one SubViewport per pass and wiring them; see
## [ShadertoyTranslator] docstring for the roadmap.

const _ShadertoyTranslator := preload("res://addons/gn_ext_shadertoy/shadertoy_translator.gd")

const _API_BASE := "https://www.shadertoy.com/api/v1/shaders/%s?key=BdHjRn"

const DEFAULT_SHADERTOY_CODE := """// Paste your Shadertoy GLSL code here.
// Example — simple colour gradient:

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    fragColor = vec4(uv, 0.5 + 0.5 * sin(iTime), 1.0);
}
"""

## Reserved uniforms (auto-bound, no inspector param).
const _RESERVED_UNIFORMS: Array = [
	"gn_resolution", "gn_mouse", "gn_frame", "gn_time_delta", "gn_date",
]

# ── Internal state ──
var _shader: Shader = null
var _last_translated_code: String = ""
var _shader_ok: bool = false
var _dynamic_param_names: PackedStringArray = PackedStringArray()
var _frame_count: int = 0
var _http: HTTPRequest = null
var _fetching: bool = false


func _init() -> void:
	node_type = "shadertoy"
	time_dependent = true
	node_description = "Paste Shadertoy GLSL or fetch by URL — auto-translates and compiles at runtime."


func _init_ports() -> void:
	# Default: generator (no inputs).  Ports rebuilt when shader is parsed.
	add_output("out", GNFamily.Type.TOP, "Shader output texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (enable for shaders using iTime)"))
	add_parameter(GNParameter.create_bool("fetch", false,
		"Fetch", "Pulse: download shader from Shadertoy URL, then auto-resets"))
	add_parameter(GNParameter.create_vector2i("resolution",
		Vector2i(512, 512), "", "Output resolution for generator shaders"))
	add_parameter(GNParameter.create_string("shadertoy_url", "",
		"Shadertoy URL", "Shadertoy page URL or shader ID (e.g. Ms2SD1)"))
	add_parameter(GNParameter.create_string("shadertoy_code",
		DEFAULT_SHADERTOY_CODE.strip_edges(),
		"Shadertoy Code", "Raw Shadertoy GLSL — translated to Godot on cook"))


# ── Pre-cook ──────────────────────────────────────────────────────────────────

func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
	if get_param_value("fetch"):
		_start_fetch()
		set_param_value("fetch", false)
	super._pre_cook(delta)


# ── Cook ──────────────────────────────────────────────────────────────────────

func _cook(inputs: Array[GNData]) -> GNData:
	# ── Resolution ──
	var res := Vector2i(512, 512)
	var has_input := inputs.size() > 0 and inputs[0] is GNTextureData
	if has_input:
		var tex_in := inputs[0] as GNTextureData
		res = tex_in.resolution
	elif parameters.has("resolution"):
		res = get_param_value("resolution")

	# ── Translate & compile on code change ──
	var st_code: String = get_param_value("shadertoy_code")
	if st_code != _last_translated_code:
		_translate_and_compile(st_code, res)
		_last_translated_code = st_code

	if not _shader_ok:
		return _cached_tex_data if _cached_tex_data != null else null

	if _viewport == null:
		_setup_viewport(res)
	if _viewport.size != res:
		_viewport.size = res

	# ── Bind auto-uniforms ──
	_material.set_shader_parameter("gn_resolution", Vector2(res))
	_material.set_shader_parameter("gn_mouse", Vector4.ZERO)
	_material.set_shader_parameter("gn_frame", _frame_count)
	_material.set_shader_parameter("gn_time_delta", get_process_delta_time())
	_frame_count += 1

	# ── Bind input textures ──
	for i in range(input_ports.size()):
		var tex: GNTextureData = inputs[i] as GNTextureData \
			if i < inputs.size() and inputs[i] is GNTextureData else null
		if tex != null:
			_material.set_shader_parameter("gn_tex%d" % i, tex.texture)

	# ── Bind dynamic uniform params ──
	for p_name in _dynamic_param_names:
		_material.set_shader_parameter(p_name, get_param_value(p_name))

	_cached_tex_data.resolution = res
	return _cached_tex_data


# ═══════════════════════════════════════════════════════════════════════════════
# Translation & Compilation
# ═══════════════════════════════════════════════════════════════════════════════

func _translate_and_compile(shadertoy_code: String, size: Vector2i) -> void:
	if shadertoy_code.strip_edges().is_empty():
		return

	var tr := _ShadertoyTranslator.translate(shadertoy_code)
	if not tr.success:
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — translation failed: %s" % [id, tr.error])
		_shader_ok = false
		return

	var godot_code := tr.godot_code
	GNLogger.info("ShadertoyURLTOP",
		"'%s' — translated %d → %d chars" % [id, shadertoy_code.length(), godot_code.length()])

	# Compile
	_setup_viewport(size)
	var new_shader := Shader.new()
	new_shader.code = godot_code
	_shader = new_shader
	_material.shader = _shader
	_shader_ok = true

	# Rebuild ports from iChannel usage
	var tex_count := tr.needs_input_tex.size()
	if tex_count > 0:
		var max_idx: int = 0
		for idx in tr.needs_input_tex:
			if idx > max_idx:
				max_idx = idx
		tex_count = max_idx + 1

	_rebuild_tex_inputs(tex_count)

	# Resolution param: only for generators
	var is_generator := tex_count == 0
	var has_res := parameters.has("resolution")
	if is_generator and not has_res:
		var res_param := GNParameter.create_vector2i("resolution",
			Vector2i(512, 512), "", "Output resolution for generator shaders")
		add_parameter(res_param)
		res_param.value_changed.connect(_on_parameter_changed)
		res_param.mode_changed.connect(_on_parameter_mode_changed)
	elif not is_generator and has_res:
		var res_param: GNParameter = parameters["resolution"]
		if res_param.value_changed.is_connected(_on_parameter_changed):
			res_param.value_changed.disconnect(_on_parameter_changed)
		if res_param.mode_changed.is_connected(_on_parameter_mode_changed):
			res_param.mode_changed.disconnect(_on_parameter_mode_changed)
		parameters.erase("resolution")

	# Rebuild uniform params from the compiled Godot code
	_rebuild_uniform_params(godot_code)


func _setup_viewport(size: Vector2i = Vector2i(512, 512)) -> void:
	if _viewport != null:
		return

	_shader = Shader.new()
	_material = ShaderMaterial.new()
	_material.shader = _shader

	_ensure_viewport(size)

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ═══════════════════════════════════════════════════════════════════════════════
# Dynamic Ports & Parameters  (mirrors CustomShaderTOP logic)
# ═══════════════════════════════════════════════════════════════════════════════

func _rebuild_tex_inputs(count: int) -> void:
	input_ports.clear()
	for i in range(count):
		add_input("in%d" % i, GNFamily.Type.TOP, false,
			"Texture input %d (iChannel%d)" % [i, i])
	GNLogger.info("ShadertoyURLTOP",
		"'%s' input ports → %d" % [id, count])
	ports_changed.emit(id)


func _rebuild_uniform_params(godot_code: String) -> void:
	var new_uniforms: Array = CustomShaderTOP._parse_uniforms(godot_code)

	# Snapshot existing dynamic param values
	var old_values: Dictionary = {}
	for p_name in _dynamic_param_names:
		var param := get_parameter(p_name)
		if param != null:
			old_values[p_name] = { "value": param.value, "type": param.value_type }

	# Remove old dynamic params
	for p_name in _dynamic_param_names:
		if parameters.has(p_name):
			var param: GNParameter = parameters[p_name]
			if param.value_changed.is_connected(_on_parameter_changed):
				param.value_changed.disconnect(_on_parameter_changed)
			if param.mode_changed.is_connected(_on_parameter_mode_changed):
				param.mode_changed.disconnect(_on_parameter_mode_changed)
			parameters.erase(p_name)
	_dynamic_param_names.clear()

	# Create new params
	for info in new_uniforms:
		var ui: CustomShaderTOP._UniformInfo = info as CustomShaderTOP._UniformInfo
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

	GNLogger.info("ShadertoyURLTOP",
		"'%s' dynamic params → %s" % [id, str(_dynamic_param_names)])
	parameters_changed.emit(id)


# ═══════════════════════════════════════════════════════════════════════════════
# URL Fetch (async via HTTPRequest)
# ═══════════════════════════════════════════════════════════════════════════════

## Extracts a Shadertoy shader ID from a URL or bare ID string.
## Accepts:  "Ms2SD1", "https://www.shadertoy.com/view/Ms2SD1", etc.
static func _extract_shader_id(url_or_id: String) -> String:
	var text := url_or_id.strip_edges()
	if text.is_empty():
		return ""
	# If it contains "/view/", grab the token after it
	var view_pos := text.find("/view/")
	if view_pos != -1:
		var after := text.substr(view_pos + 6).strip_edges().rstrip("/")
		# Take only alphanumeric chars
		var result := ""
		for c in after:
			if c.is_valid_identifier() or c.is_valid_int():
				result += c
			else:
				break
		return result
	# Otherwise assume it's already a bare ID
	return text


func _start_fetch() -> void:
	var url_str: String = get_param_value("shadertoy_url")
	var shader_id := _extract_shader_id(url_str)
	if shader_id.is_empty():
		GNLogger.warn("ShadertoyURLTOP",
			"'%s' — no valid Shadertoy URL or ID to fetch" % id)
		return
	if _fetching:
		GNLogger.warn("ShadertoyURLTOP",
			"'%s' — fetch already in progress" % id)
		return

	# Ensure HTTPRequest node exists
	if _http == null:
		_http = HTTPRequest.new()
		_http.name = "ShadertoyHTTP"
		# Attach to the viewport (it's in the scene tree)
		if _viewport != null:
			_viewport.add_child(_http)
		else:
			# Viewport not yet created — create one first
			_setup_viewport(Vector2i(512, 512))
			_viewport.add_child(_http)
		_http.request_completed.connect(_on_fetch_completed)

	var api_url := _API_BASE % shader_id
	GNLogger.info("ShadertoyURLTOP",
		"'%s' — fetching shader '%s'" % [id, shader_id])
	_fetching = true
	var err := _http.request(api_url)
	if err != OK:
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — HTTP request failed: %s" % [id, error_string(err)])
		_fetching = false


func _on_fetch_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetching = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — fetch failed (HTTP %d, result %d)" % [id, response_code, result])
		return

	var json := JSON.new()
	var parse_err := json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — JSON parse error: %s" % [id, json.get_error_message()])
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	if data.has("Error"):
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — Shadertoy API error: %s" % [id, data["Error"]])
		return

	# Extract the Image pass code
	var shader_info: Dictionary = data.get("Shader", {})
	var renderpasses: Array = shader_info.get("renderpass", [])
	var image_code := ""
	for rp in renderpasses:
		if rp is Dictionary and rp.get("type", "") == "image":
			image_code = rp.get("code", "")
			break

	if image_code.is_empty():
		GNLogger.error("ShadertoyURLTOP",
			"'%s' — no 'image' renderpass found in API response" % id)
		return

	# Populate the code param — the next cook will auto-translate
	set_param_value("shadertoy_code", image_code)
	GNLogger.info("ShadertoyURLTOP",
		"'%s' — fetched %d chars of Shadertoy code" % [id, image_code.length()])
	mark_dirty()


# ── Serialisation ─────────────────────────────────────────────────────────────

func from_dict(d: Dictionary) -> void:
	super.from_dict(d)

	var st_code: String = get_param_value("shadertoy_code")
	if not st_code.is_empty():
		var init_size := Vector2i(512, 512)
		if parameters.has("resolution"):
			init_size = get_param_value("resolution")
		_translate_and_compile(st_code, init_size)
		_last_translated_code = st_code

	# Restore dynamic param values
	if d.has("parameters"):
		var params_dict: Dictionary = d["parameters"]
		for param_name in params_dict:
			if param_name in ["resolution", "shadertoy_code", "shadertoy_url",
					"time_dependent", "fetch"]:
				continue
			var param: GNParameter = parameters.get(param_name, null)
			if param != null:
				param.from_dict(params_dict[param_name])
