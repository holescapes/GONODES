class_name ShadertoyTOP
extends GNTopBase
## Shadertoy GLSL shader node — inline editor + runtime translation pipeline.
##
## Write or paste raw Shadertoy GLSL (void mainImage format) directly in the
## inspector or open the full code editor with Shadertoy syntax highlighting
## and the Presets menu (factory presets in addons/gn_ext_shadertoy/presets/shadertoy/).
##
## Optionally set shadertoy_url and pulse fetch to download any public shader
## from the Shadertoy API — the code lands in shadertoy_code and is compiled
## immediately on the next cook.
##
## ── Translation pipeline ──────────────────────────────────────────────────────
##   mainImage GLSL → ShadertoyTranslator → Godot canvas_item shader
##   iTime/iResolution/iMouse auto-bound; uniform declarations → inspector params;
##   iChannel0..3 usage → auto-generated TOP input ports.
##
## ── Presets ───────────────────────────────────────────────────────────────────
##   Factory presets in addons/gn_ext_shadertoy/presets/shadertoy/ (.glsl)
##   User presets in user://gonodes_presets/shadertoy/

const _API_BASE := "https://www.shadertoy.com/api/v1/shaders/%s?key=%s"

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
	add_output("out", GNFamily.Type.TOP, "Shader output texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (enable for shaders using iTime)"))
	var fetch_param := GNParameter.create_pulse("fetch",
		"Fetch", "Download shader from the Shadertoy URL")
	fetch_param.value_changed.connect(_on_fetch_changed)
	add_parameter(fetch_param)
	add_parameter(GNParameter.create_vector2i("resolution",
		Vector2i(512, 512), "", "Output resolution for generator shaders"))
	add_parameter(GNParameter.create_string("shadertoy_url", "The shadertoy url string",
		"Shadertoy URL", "Shadertoy page URL or shader ID (e.g. Ms2SD1)"))
	add_parameter(GNParameter.create_string("shadertoy_api_key", "The shadertoy api key string",
		"API Key", "Your Shadertoy API key — register at shadertoy.com/myapps"))
	add_parameter(GNParameter.create_string("shadertoy_code",
		DEFAULT_SHADERTOY_CODE.strip_edges(),
		"Shadertoy Code", "Raw Shadertoy GLSL — translated to Godot on cook"))


func _on_fetch_changed(_p_name: String, new_value: Variant) -> void:
	if new_value == true:
		set_param_value("fetch", false)
		_start_fetch()


# ── Pre-cook ──────────────────────────────────────────────────────────────────

func _pre_cook(delta: float) -> void:
	time_dependent = get_param_value("time_dependent")
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
		return null

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
	# Empty code → clear shader, return null → X icon
	if shadertoy_code.strip_edges().is_empty():
		_shader_ok = false
		if _material != null:
			_material.shader = null
		_dynamic_param_names.clear()
		return

	var tr := ShadertoyTranslator.translate(shadertoy_code)
	if not tr.success:
		GNLogger.error("ShadertoyTOP",
			"'%s' — translation failed: %s" % [id, tr.error])
		_shader_ok = false
		return

	var godot_code := tr.godot_code
	GNLogger.info("ShadertoyTOP",
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
	GNLogger.info("ShadertoyTOP",
		"'%s' input ports → %d" % [id, count])
	ports_changed.emit(id)


func _rebuild_uniform_params(godot_code: String) -> void:
	var new_uniforms: Array = CustomShaderTOP._parse_uniforms(godot_code)

	# Filter out Shadertoy auto-bound uniforms that CustomShaderTOP doesn't know about
	var filtered: Array = []
	for info in new_uniforms:
		var ui: CustomShaderTOP._UniformInfo = info as CustomShaderTOP._UniformInfo
		if ui.uniform_name not in _RESERVED_UNIFORMS:
			filtered.append(info)
	new_uniforms = filtered

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
		_dynamic_param_names.append(ui.uniform_name)

	GNLogger.info("ShadertoyTOP",
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
		GNLogger.warn("ShadertoyTOP",
			"'%s' — no valid Shadertoy URL or ID to fetch" % id)
		return
	if _fetching:
		GNLogger.warn("ShadertoyTOP",
			"'%s' — fetch already in progress" % id)
		return

	if _http == null:
		_http = HTTPRequest.new()
		_http.name = "ShadertoyHTTP"
		_http.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_http)
		_http.request_completed.connect(_on_fetch_completed)

	var api_key: String = get_param_value("shadertoy_api_key").strip_edges()
	if api_key.is_empty():
		GNLogger.error("ShadertoyTOP",
			"'%s' — no API key. Register one at shadertoy.com/myapps" % id)
		_fetching = false
		return

	var api_url := _API_BASE % [shader_id, api_key]
	GNLogger.info("ShadertoyTOP", "'%s' — fetching '%s'" % [id, shader_id])
	_fetching = true
	var err := _http.request(api_url)
	if err != OK:
		GNLogger.error("ShadertoyTOP",
			"'%s' — HTTP request failed: %s" % [id, error_string(err)])
		_fetching = false


func _on_fetch_completed(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetching = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		GNLogger.error("ShadertoyTOP",
			"'%s' — fetch failed (HTTP %d, result %d)" % [id, response_code, result])
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		GNLogger.error("ShadertoyTOP",
			"'%s' — JSON parse error: %s" % [id, json.get_error_message()])
		return

	var data: Dictionary = json.data if json.data is Dictionary else {}
	if data.has("Error"):
		GNLogger.error("ShadertoyTOP",
			"'%s' — Shadertoy API error: %s" % [id, data["Error"]])
		return

	var renderpasses: Array = data.get("Shader", {}).get("renderpass", [])
	var image_code := ""
	for rp in renderpasses:
		if rp is Dictionary and rp.get("type", "") == "image":
			image_code = rp.get("code", "")
			break

	if image_code.is_empty():
		GNLogger.error("ShadertoyTOP",
			"'%s' — no 'image' renderpass in API response" % id)
		return

	GNLogger.info("ShadertoyTOP",
		"'%s' — fetched %d chars" % [id, image_code.length()])
	set_param_value("shadertoy_code", image_code)
	parameters_changed.emit(id)
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
