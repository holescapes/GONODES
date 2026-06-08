class_name ISFTOP
extends GNTopBase
## ISF (Interactive Shader Format) shader node.
##
## Supports the full ISF v2 specification via inline code editing:
##   • Single-pass generators, FX and transitions
##   • Multi-pass shaders (PASSES array with TARGET names)
##   • Persistent buffers (PERSISTENT + FLOAT keys)
##   • Per-pass WIDTH/HEIGHT expressions ($WIDTH, $HEIGHT, $inputName)
##   • All ISF input types → auto-generated GNParameters
##   • image inputs → auto-generated TOP input ports
##
## ── Workflow ─────────────────────────────────────────────────────────────────
##   • Edit isf_code inline or click "Edit ↗" for the full code editor
##     (ISF syntax highlighting, Presets menu, preset save/load)
##   • Set isf_file to load any external .fs/.isf file into isf_code
##   • Parameters auto-appear from JSON INPUTS on compile
##   • Input ports auto-appear for image-type INPUTS
##
## ── Presets ──────────────────────────────────────────────────────────────────
##   Factory presets in addons/gn_ext_isf/presets/isf/ (.fs files)
##   User presets in user://gonodes_presets/isf/


const DEFAULT_ISF_CODE := \
"""/*{
	"DESCRIPTION": "New ISF shader",
	"CREDIT": "",
	"ISFVSN": "2.0",
	"CATEGORIES": ["Generator"],
	"INPUTS": [
		{
			"NAME": "speed",
			"TYPE": "float",
			"DEFAULT": 1.0,
			"MIN": 0.0,
			"MAX": 5.0
		}
	]
}*/

void main() {
	// isf_FragNormCoord -> normalised UV  (0,0 bottom-left, 1,1 top-right)
	// gl_FragColor      -> output colour
	// TIME              -> elapsed seconds
	// RENDERSIZE        -> canvas size in pixels
	vec2 uv = isf_FragNormCoord;
	gl_FragColor = vec4(uv, 0.5 + 0.5 * sin(TIME * speed), 1.0);
}
"""


# ── Internal state ────────────────────────────────────────────────────────────

var _isf_result: ISFTranslator.TranslationResult = null
var _shader: Shader = null
var _pass_shaders: Array[Shader] = []
var _pass_viewports: Array[SubViewport] = []
var _pass_materials: Array[ShaderMaterial] = []
var _pass_tex_data: Array[GNTextureData] = []
var _frame_count: int = 0
var _compiled: bool = false
var _last_compiled_code: String = ""
var _last_file_path: String = ""
var _isf_param_names: PackedStringArray = PackedStringArray()
var _vertex_source: String = ""
var _imported_base_dir: String = ""
var _imported_textures: Dictionary = {}  # name → ImageTexture


# ===============================================================================
# Lifecycle
# ===============================================================================

func _init() -> void:
	node_type = "isf"
	time_dependent = true
	node_description = "ISF shader node — inline code editor with auto-parameters, multi-pass and persistent buffers. Load presets or write your own ISF GLSL."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "ISF shader output texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("time_dependent", true,
		"Time Dependent", "Re-cook every frame (enable for shaders using TIME)"))
	add_parameter(GNParameter.create_file("isf_file", "Path to the isf file",
		PackedStringArray(["*.fs", "*.isf", "*.frag"]),
		"ISF File", "Load an external ISF file into the code editor below"))
	add_parameter(GNParameter.create_vector2i("resolution",
		Vector2i(512, 512), "", "Output resolution for generator shaders"))
	add_parameter(GNParameter.create_string("isf_code",
		DEFAULT_ISF_CODE.strip_edges(),
		"ISF Code", "ISF source (JSON header + GLSL body) — compiled on change"))


func _pre_cook(_delta: float) -> void:
	time_dependent = get_param_value("time_dependent")

	# File load: copy file content into isf_code whenever path changes
	var file_path: String = get_param_value("isf_file")
	if not file_path.is_empty() and file_path != _last_file_path:
		_load_file_to_code(file_path)
		_last_file_path = file_path

	# Compile whenever isf_code changes
	var code: String = get_param_value("isf_code")
	if code != _last_compiled_code:
		_compile(code)

	super._pre_cook(_delta)


## Rebuild dynamic ISF params from saved isf_code BEFORE restoring their values.
func from_dict(d: Dictionary) -> void:
	super.from_dict(d)
	var code: String = get_param_value("isf_code")
	if not code.is_empty():
		_compile(code)
	if d.has("parameters"):
		var pd: Dictionary = d["parameters"]
		for p_name in pd:
			if p_name in ["time_dependent", "isf_file", "resolution", "isf_code"]:
				continue
			var param: GNParameter = parameters.get(p_name, null)
			if param != null:
				param.from_dict(pd[p_name])


# ===============================================================================
# File Loading
# ===============================================================================

func _load_file_to_code(path: String) -> void:
	var resolved := GNResourceLoader.resolve(path, project_dir)
	if resolved.is_empty():
		GNLogger.error("ISFTOP", "'%s' — file not found: %s" % [id, path])
		return

	# ── If path points to a directory, find the .fs inside it ──
	if DirAccess.dir_exists_absolute(resolved):
		var fs_path := _find_fs_in_dir(resolved)
		if fs_path.is_empty():
			GNLogger.error("ISFTOP", "'%s' — no .fs file found in folder: %s" % [id, resolved])
			return
		resolved = fs_path

	if not FileAccess.file_exists(resolved):
		GNLogger.error("ISFTOP", "'%s' — file not found: %s" % [id, path])
		return

	# ── Read fragment shader ──
	var file := FileAccess.open(resolved, FileAccess.READ)
	if file == null:
		GNLogger.error("ISFTOP", "'%s' — cannot open: %s" % [id, path])
		return
	set_param_value("isf_code", file.get_as_text())
	file.close()

	# ── Remember base directory for IMPORTED image resolution ──
	_imported_base_dir = resolved.get_base_dir()

	# ── Look for companion .vs vertex shader ──
	_vertex_source = ""
	var base_name := resolved.get_file().get_basename()
	var vs_path := _imported_base_dir.path_join(base_name + ".vs")
	if FileAccess.file_exists(vs_path):
		var vs_file := FileAccess.open(vs_path, FileAccess.READ)
		if vs_file != null:
			_vertex_source = vs_file.get_as_text()
			vs_file.close()
			GNLogger.info("ISFTOP", "'%s' — loaded companion VS: %s" % [id, vs_path.get_file()])

	GNLogger.info("ISFTOP", "'%s' — loaded %s" % [id, resolved.get_file()])


## Find the first .fs file inside a directory.
static func _find_fs_in_dir(dir_path: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var fname := dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.get_extension().to_lower() == "fs":
			dir.list_dir_end()
			return dir_path.path_join(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return ""


# ===============================================================================
# ISF Compilation
# ===============================================================================

func _compile(source: String) -> void:
	_last_compiled_code = source
	if source.strip_edges().is_empty():
		return

	var result := ISFTranslator.translate(source, _vertex_source)
	if not result.success:
		GNLogger.error("ISFTOP",
			"'%s' — ISF translation failed: %s" % [id, result.error])
		_compiled = false
		return

	_isf_result = result

	# ── Rebuild image-input ports ──
	input_ports.clear()
	for i in range(result.image_inputs.size()):
		add_input(result.image_inputs[i], GNFamily.Type.TOP, false,
			"ISF image input '%s'" % result.image_inputs[i])
	ports_changed.emit(id)

	# ── resolution param: present for generators, removed for FX ──
	var is_gen := result.is_generator
	if is_gen and not parameters.has("resolution"):
		var rp := GNParameter.create_vector2i("resolution",
			Vector2i(512, 512), "", "Output resolution for generator shaders")
		_insert_param_before("isf_code", "resolution", rp)
	elif not is_gen and parameters.has("resolution"):
		_remove_param("resolution")

	# ── ISF INPUT params ──
	_remove_isf_params()
	_build_isf_params()

	# ── Compile Godot shader(s) ──
	var pass_count := result.passes.size()
	var was_multipass := _pass_shaders.size() > 1
	var is_multipass := pass_count > 1

	# Only destroy viewport when switching between single↔multi-pass.
	# Reusing Shader objects avoids expensive GPU re-allocation.
	if was_multipass != is_multipass:
		_cleanup_pass_viewports()
		if _viewport != null:
			_viewport.queue_free()
			_viewport = null
			_material = null
			_canvas = null

	if not is_multipass:
		if _shader == null:
			_shader = Shader.new()
		_shader.code = result.godot_code
		_pass_shaders.clear()
		# Update the existing material if the viewport survived
		if _material != null:
			_material.shader = _shader
	else:
		_shader = null
		# Reuse existing pass shaders where possible
		while _pass_shaders.size() > pass_count:
			_pass_shaders.pop_back()
		for i in range(pass_count):
			if i < _pass_shaders.size():
				_pass_shaders[i].code = result.pass_codes[i]
			else:
				var s := Shader.new()
				s.code = result.pass_codes[i]
				_pass_shaders.append(s)

	_compiled = true
	_load_imported_images()
	GNLogger.info("ISFTOP",
		"'%s' — compiled (%d passes, %d ISF params, %d image ports)" % [
			id, maxi(result.passes.size(), 1),
			_isf_param_names.size(), result.image_inputs.size()])


func _remove_isf_params() -> void:
	for p_name in _isf_param_names:
		_remove_param(p_name)
	_isf_param_names.clear()


func _remove_param(p_name: String) -> void:
	if not parameters.has(p_name):
		return
	var param: GNParameter = parameters[p_name]
	if param.value_changed.is_connected(_on_parameter_changed):
		param.value_changed.disconnect(_on_parameter_changed)
	if param.mode_changed.is_connected(_on_parameter_mode_changed):
		param.mode_changed.disconnect(_on_parameter_mode_changed)
	parameters.erase(p_name)


func _insert_param_before(anchor: String, new_name: String,
		new_param: GNParameter) -> void:
	var snapshot: Array = []
	for k in parameters:
		snapshot.append({"k": k, "p": parameters[k]})
	parameters.clear()
	var inserted := false
	for entry in snapshot:
		if entry["k"] == anchor and not inserted:
			parameters[new_name] = new_param
			new_param.value_changed.connect(_on_parameter_changed)
			new_param.mode_changed.connect(_on_parameter_mode_changed)
			inserted = true
		parameters[entry["k"]] = entry["p"]
	if not inserted:
		parameters[new_name] = new_param
		new_param.value_changed.connect(_on_parameter_changed)
		new_param.mode_changed.connect(_on_parameter_mode_changed)


func _build_isf_params() -> void:
	for inp in _isf_result.inputs:
		if inp.type in ["image", "audio", "audiofft"]:
			continue
		var lbl := inp.label if not inp.label.is_empty() else ""
		var param: GNParameter = null
		match inp.type:
			"float":
				var def := float(inp.default_value) if inp.default_value != null else 0.5
				var mn: Variant = float(inp.min_value) if inp.min_value != null else null
				var mx: Variant = float(inp.max_value) if inp.max_value != null else null
				param = GNParameter.create_float(inp.input_name, def, mn, mx, 0.01, lbl,
					"ISF float input")
			"bool":
				param = GNParameter.create_bool(inp.input_name,
					bool(inp.default_value) if inp.default_value != null else false,
					lbl, "ISF bool input")
			"long":
				if inp.labels.size() > 0:
					var opts := PackedStringArray()
					for l in inp.labels:
						opts.append(str(l))
					var def_idx := 0
					if inp.default_value != null:
						for i in range(inp.values.size()):
							if int(inp.values[i]) == int(inp.default_value):
								def_idx = i; break
					param = GNParameter.create_enum(inp.input_name, opts, def_idx,
						lbl, "ISF menu input")
				else:
					param = GNParameter.create_int(inp.input_name,
						int(inp.default_value) if inp.default_value != null else 0,
						null, null, lbl, "ISF long input")
			"point2d":
				var dv := Vector2.ZERO
				if inp.default_value is Array and inp.default_value.size() >= 2:
					dv = Vector2(float(inp.default_value[0]), float(inp.default_value[1]))
				param = GNParameter.create_vector2(inp.input_name, dv, lbl,
					"ISF point2D input")
			"color":
				var dc := Color.WHITE
				if inp.default_value is Array:
					var a: Array = inp.default_value
					if a.size() >= 3:
						dc = Color(float(a[0]), float(a[1]), float(a[2]),
							float(a[3]) if a.size() >= 4 else 1.0)
				param = GNParameter.create_color(inp.input_name, dc, lbl,
					"ISF color input")
			"event":
				param = GNParameter.create_bool(inp.input_name, false, lbl,
					"ISF event — pulses true for one frame")
		if param != null:
			add_parameter(param)
			_isf_param_names.append(inp.input_name)

	parameters_changed.emit(id)


# ===============================================================================
# IMPORTED Image Loading
# ===============================================================================

func _load_imported_images() -> void:
	_imported_textures.clear()
	if _isf_result == null or _isf_result.imported_images.is_empty():
		return
	if _imported_base_dir.is_empty():
		return

	for img_name in _isf_result.imported_images:
		var entry: Dictionary = _isf_result.imported_images[img_name]
		var rel_path: String = entry.get("PATH", "")
		if rel_path.is_empty():
			continue
		var abs_path := _imported_base_dir.path_join(rel_path)
		if not FileAccess.file_exists(abs_path):
			GNLogger.warn("ISFTOP", "'%s' — IMPORTED image not found: %s" % [id, abs_path])
			continue
		var img := Image.new()
		var err := img.load(abs_path)
		if err != OK:
			GNLogger.warn("ISFTOP", "'%s' — failed to load IMPORTED image: %s" % [id, abs_path])
			continue
		var tex := ImageTexture.create_from_image(img)
		_imported_textures[img_name] = tex
		GNLogger.info("ISFTOP", "'%s' — loaded IMPORTED '%s' (%dx%d)" % [
			id, img_name, img.get_width(), img.get_height()])


# ===============================================================================
# Cook
# ===============================================================================

func _cook(inputs: Array[GNData]) -> GNData:
	if not _compiled or _isf_result == null:
		return null
	var res := _resolve_resolution(inputs)
	if _isf_result.passes.size() <= 1:
		return _cook_single_pass(inputs, res)
	return _cook_multi_pass(inputs, res)


func _resolve_resolution(inputs: Array[GNData]) -> Vector2i:
	if not _isf_result.is_generator and inputs.size() > 0 and inputs[0] is GNTextureData:
		return (inputs[0] as GNTextureData).resolution
	if parameters.has("resolution"):
		return get_param_value("resolution")
	return Vector2i(512, 512)


func _cook_single_pass(inputs: Array[GNData], res: Vector2i) -> GNData:
	if _viewport == null:
		_ensure_viewport(res, true)
		_material = ShaderMaterial.new()
		_material.shader = _shader
		var canvas := ColorRect.new()
		canvas.name = "Canvas"
		canvas.material = _material
		_viewport.add_child(canvas)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_canvas = canvas

	if _viewport.size != res:
		_viewport.size = res
	_bind_uniforms(_material, inputs, res)
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _cook_multi_pass(inputs: Array[GNData], res: Vector2i) -> GNData:
	_ensure_pass_viewports(res)

	for pass_idx in range(_isf_result.passes.size()):
		var p: ISFTranslator.ISFPass = _isf_result.passes[pass_idx]
		var mat: ShaderMaterial = _pass_materials[pass_idx]
		var vp: SubViewport = _pass_viewports[pass_idx]
		var pass_res := _evaluate_pass_size(p, res)
		if vp.size != pass_res:
			vp.size = pass_res

		_bind_uniforms(mat, inputs, pass_res)
		mat.set_shader_parameter("isf_pass_index", pass_idx)

		for prev in range(pass_idx):
			var pp: ISFTranslator.ISFPass = _isf_result.passes[prev]
			if not pp.target.is_empty():
				mat.set_shader_parameter(pp.target, _pass_viewports[prev].get_texture())
				mat.set_shader_parameter("isf_%s_size" % pp.target,
					Vector2(_pass_viewports[prev].size))

		if p.persistent and not p.target.is_empty():
			mat.set_shader_parameter(p.target, vp.get_texture())
			mat.set_shader_parameter("isf_%s_size" % p.target, Vector2(vp.size))

		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	var last := _isf_result.passes.size() - 1
	_cached_tex_data = _pass_tex_data[last]
	_cached_tex_data.resolution = _pass_viewports[last].size
	return _cached_tex_data


# ===============================================================================
# Multi-Pass Viewport Management
# ===============================================================================

func _ensure_pass_viewports(base_res: Vector2i) -> void:
	if _pass_viewports.size() == _isf_result.passes.size():
		return
	_cleanup_pass_viewports()

	for pass_idx in range(_isf_result.passes.size()):
		var p: ISFTranslator.ISFPass = _isf_result.passes[pass_idx]
		var pass_res := _evaluate_pass_size(p, base_res)

		var vp := SubViewport.new()
		vp.name = "Pass_%d_%s" % [pass_idx, p.target if not p.target.is_empty() else "out"]
		vp.size = pass_res
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.disable_3d = true
		vp.gui_disable_input = true
		if p.persistent:
			vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
		if p.is_float:
			vp.use_hdr_2d = true
		add_child(vp)

		var mat := ShaderMaterial.new()
		mat.shader = _pass_shaders[pass_idx] if pass_idx < _pass_shaders.size() \
			else (_shader if _shader != null else Shader.new())

		var canvas := ColorRect.new()
		canvas.name = "Canvas"
		canvas.material = mat
		vp.add_child(canvas)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var td := GNTextureData.new()
		td.texture = vp.get_texture()
		td.viewport = vp
		td.resolution = pass_res

		_pass_viewports.append(vp)
		_pass_materials.append(mat)
		_pass_tex_data.append(td)


func _cleanup_pass_viewports() -> void:
	for vp in _pass_viewports:
		if is_instance_valid(vp) and vp.get_parent() != null:
			vp.get_parent().remove_child(vp)
			vp.queue_free()
	_pass_viewports.clear()
	_pass_materials.clear()
	_pass_tex_data.clear()


func _evaluate_pass_size(p: ISFTranslator.ISFPass, base_res: Vector2i) -> Vector2i:
	if p.width_expr.is_empty() and p.height_expr.is_empty():
		return base_res
	var w := _eval_size_expr(p.width_expr, base_res) if not p.width_expr.is_empty() else base_res.x
	var h := _eval_size_expr(p.height_expr, base_res) if not p.height_expr.is_empty() else base_res.y
	return Vector2i(maxi(w, 1), maxi(h, 1))


func _eval_size_expr(expr_str: String, base_res: Vector2i) -> int:
	var s := expr_str.replace("$WIDTH", str(base_res.x)).replace("$HEIGHT", str(base_res.y))
	for p_name in _isf_param_names:
		s = s.replace("$%s" % p_name, str(get_param_value(p_name)))
	var expr := Expression.new()
	if expr.parse(s) != OK:
		return base_res.x
	var val = expr.execute()
	return base_res.x if expr.has_execute_failed() else int(val)


# ===============================================================================
# Uniform Binding
# ===============================================================================

func _bind_uniforms(mat: ShaderMaterial, inputs: Array[GNData], res: Vector2i) -> void:
	mat.set_shader_parameter("isf_rendersize", Vector2(res))
	if _isf_result.uses_time_delta:
		mat.set_shader_parameter("isf_time_delta", get_process_delta_time())
	if _isf_result.uses_date:
		var dt := Time.get_datetime_dict_from_system()
		mat.set_shader_parameter("isf_date", Vector4(
			float(dt.get("year", 2026)), float(dt.get("month", 1)),
			float(dt.get("day", 1)),
			float(dt.get("hour", 0)) * 3600.0 + float(dt.get("minute", 0)) * 60.0
			+ float(dt.get("second", 0))))
	if _isf_result.uses_frame_index:
		mat.set_shader_parameter("isf_frame_index", _frame_count)
	_frame_count += 1

	for inp in _isf_result.inputs:
		match inp.type:
			"float", "bool":
				if parameters.has(inp.input_name):
					mat.set_shader_parameter(inp.input_name, get_param_value(inp.input_name))
			"event":
				if parameters.has(inp.input_name):
					var val: bool = get_param_value(inp.input_name)
					mat.set_shader_parameter(inp.input_name, val)
					if val:
						set_param_value(inp.input_name, false)
			"long":
				if parameters.has(inp.input_name):
					var idx: int = get_param_value(inp.input_name)
					mat.set_shader_parameter(inp.input_name,
						int(inp.values[idx]) if idx < inp.values.size() else idx)
			"point2d":
				if parameters.has(inp.input_name):
					mat.set_shader_parameter(inp.input_name, get_param_value(inp.input_name))
			"color":
				if parameters.has(inp.input_name):
					var c: Color = get_param_value(inp.input_name)
					mat.set_shader_parameter(inp.input_name, Vector4(c.r, c.g, c.b, c.a))
			"image":
				var port_idx := _isf_result.image_inputs.find(inp.input_name)
				if port_idx != -1 and port_idx < inputs.size() \
						and inputs[port_idx] is GNTextureData:
					var td := inputs[port_idx] as GNTextureData
					mat.set_shader_parameter(inp.input_name, td.texture)
					mat.set_shader_parameter("isf_%s_size" % inp.input_name,
						Vector2(td.resolution))

	# ── IMPORTED image textures ──
	for img_name in _imported_textures:
		var tex: ImageTexture = _imported_textures[img_name]
		mat.set_shader_parameter(img_name, tex)
		mat.set_shader_parameter("isf_%s_size" % img_name,
			Vector2(tex.get_width(), tex.get_height()))
