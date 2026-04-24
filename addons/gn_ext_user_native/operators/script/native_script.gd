class_name NativeSCRIPT
extends GNNode
## Native C++ scripting node with hot-reloadable compilation.
##
## Ports and parameters are defined dynamically in the C++ source via
## `get_port_definitions()` / `get_param_definitions()`.  Use presets to
## load starting-point code for different families.

const _DEFAULT_SOURCE := \
"""/*  CHOP Template — Minimal starting point for a UserNativeCHOP.
 *  Generates a single sine wave channel.
 */
#ifndef USER_CHOP_TEMPLATE_H
#define USER_CHOP_TEMPLATE_H

#include <gn_user_node.h>
#include <gn_user_chop.h>

using namespace godot;

class MyUserCHOP : public gn::GNUserNode {
	GDCLASS(MyUserCHOP, gn::GNUserNode)
protected:
	static void _bind_methods() { gn::GNUserNode::_bind_methods(); }
public:
	String get_node_type() const override { return "my_user_chop"; }
	String get_node_description() const override { return "My custom CHOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Output channels";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		params.push_back(gn::parf("frequency", 1.0, 0.01, 100.0, 0.01,
			"Frequency", "Oscillation frequency in Hz."));
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float freq = parf(params, "frequency", 1.0);
		float elapsed = parf(context, "elapsed", 0.0);
		PackedFloat32Array arr;
		arr.push_back(sin(elapsed * freq * Math_TAU));
		return gn::make_chop_single("value", arr);
	}
};

#endif
"""

## System parameter names (not forwarded to native code).
const _SYSTEM_PARAMS: PackedStringArray = ["cpp_source", "auto_build", "time_dep"]


# ═══════════════════════════════════════════════════════════════════════════════
# Instance State
# ═══════════════════════════════════════════════════════════════════════════════

var _processor: RefCounted = null
var _compiler: GNNativeCompiler = null
var _reloader: GNNativeReloader = null
var _file_watch: GNNativeFileWatch = null
var _code_editor: GNCppCodeEditor = null
var _cpp_source: String = ""
var _cpp_class: String = "MyUserCHOP"
var _compile_error: String = ""
var _is_compiled: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []

## Last cook duration in milliseconds (for preview display).
var _last_cook_ms: float = 0.0

## Per-port output data for multi-output support.
var _output_data: Array[GNData] = []

## TOP-specific: viewport infrastructure for shader rendering.
var _viewport: SubViewport = null
var _material: ShaderMaterial = null
var _cached_tex: GNTextureData = null


func _init() -> void:
	family = GNFamily.Type.SCRIPT
	node_type = "nativescript"
	node_description = "User Native SCRIPT — hot-reloadable C++ processing at native speed."
	_compiler = GNNativeCompiler.new()
	_reloader = GNNativeReloader.new()
	_file_watch = GNNativeFileWatch.new()
	_file_watch.file_changed.connect(_on_source_file_changed)
	_cpp_source = _DEFAULT_SOURCE


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Output channels")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("cpp_source", _DEFAULT_SOURCE,
		"C++ Source", "C++ source code. Click 'Edit C++ ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_build", true,
		"Auto Build", "Automatically rebuild on source change."))
	add_parameter(GNParameter.create_bool("time_dep", true,
		"Time Dependent", "Recook every frame."))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")

	var source: String = get_param_value("cpp_source")
	if source != _cpp_source:
		_cpp_source = source
		if get_param_value("auto_build"):
			_trigger_build()

	if _processor != null:
		var t0 := Time.get_ticks_usec()
		var result := _cook_native(inputs)
		_last_cook_ms = (Time.get_ticks_usec() - t0) / 1000.0
		return result

	if not _compile_error.is_empty():
		node_warning = "C++ compile error: %s" % _compile_error
	elif not _is_compiled:
		node_warning = "C++ not compiled. Click 'Edit C++ ↗' and press Build."
	return null


func _cook_native(inputs: Array[GNData]) -> GNData:
	var params := _gather_user_params()
	var input_dicts := _marshal_inputs(inputs)
	var context := {"delta": current_delta, "elapsed": elapsed_time, "frame": current_frame}

	var result: Dictionary = _processor.native_cook(params, input_dicts, context)
	if result.is_empty():
		return null

	if result.has("error"):
		node_warning = "Native cook error: %s" % str(result["error"]).substr(0, 200)
		return null

	node_warning = ""

	# Multi-output: {"outputs": [dict0, dict1, ...]}
	if result.has("outputs"):
		return _build_multi_output(result["outputs"], inputs)

	# Single-output (backwards-compatible)
	_output_data.clear()
	var data := _build_output_for_port(result, 0, inputs)
	if data != null:
		_output_data.append(data)
	return data


# ═══════════════════════════════════════════════════════════════════════════════
# Input Marshalling — dispatch by port family
# ═══════════════════════════════════════════════════════════════════════════════

func _marshal_inputs(inputs: Array[GNData]) -> Array:
	var input_dicts := Array()
	for i in range(input_ports.size()):
		var in_data: GNData = inputs[i] if i < inputs.size() else null
		if in_data == null:
			input_dicts.append(null)
			continue
		var port_family: int = input_ports[i].family
		match port_family:
			GNFamily.Type.CHOP: input_dicts.append(_marshal_chop(in_data))
			GNFamily.Type.SOP:  input_dicts.append(_marshal_sop(in_data))
			GNFamily.Type.DAT:  input_dicts.append(_marshal_dat(in_data))
			GNFamily.Type.IMG:  input_dicts.append(_marshal_img(in_data))
			GNFamily.Type.TOP:  input_dicts.append({"family": "TOP"})
			_:                  input_dicts.append(_marshal_extension(in_data))
	return input_dicts


func _marshal_chop(data: GNData) -> Variant:
	if data is GNChannelData:
		var cd: GNChannelData = data as GNChannelData
		return {"channels": cd.channels.duplicate(), "sample_rate": cd.sample_rate, "length": cd.length}
	return null


func _marshal_sop(data: GNData) -> Variant:
	if data is GNGeoData:
		var geo: GNGeoData = data as GNGeoData
		return {"positions": geo.get_positions(), "normals": geo.get_normals(),
				"uvs": geo.get_uvs(), "vertex_count": geo.vertex_count}
	return null


func _marshal_dat(data: GNData) -> Variant:
	if data is GNTableData:
		var dat: GNTableData = data as GNTableData
		return {"headers": dat.headers.duplicate(), "rows": dat.rows.duplicate(),
				"text": dat.text if dat.text != null else ""}
	return null


func _marshal_img(data: GNData) -> Variant:
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null:
			return {"image": img_data.image,
					"width": img_data.image.get_width(),
					"height": img_data.image.get_height()}
	return null


## Generic extension family marshalling — supports SDF and future extensions.
## Convention: if the data has a known property (e.g. sdf_tree), serialize it.
func _marshal_extension(data: GNData) -> Variant:
	# SDF data: carries an AST tree dictionary
	if "sdf_tree" in data and "tree_hash" in data:
		return {"sdf_tree": data.get("sdf_tree"), "tree_hash": data.get("tree_hash")}
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Output Building — dispatch by port family
# ═══════════════════════════════════════════════════════════════════════════════

## Builds per-port output data from an array of result dicts.
func _build_multi_output(outputs_arr: Array, inputs: Array[GNData]) -> GNData:
	_output_data.clear()
	for i in range(mini(outputs_arr.size(), output_ports.size())):
		var port_result = outputs_arr[i]
		if port_result is Dictionary and not port_result.is_empty():
			_output_data.append(_build_output_for_port(port_result, i, inputs))
		else:
			_output_data.append(null)
	return _output_data[0] if not _output_data.is_empty() else null


## Builds typed GNData for a single port from its result dictionary.
func _build_output_for_port(result: Dictionary, port_index: int, inputs: Array[GNData]) -> GNData:
	if port_index < 0 or port_index >= output_ports.size():
		return null
	var out_family: int = output_ports[port_index].family
	match out_family:
		GNFamily.Type.CHOP: return _build_chop(result)
		GNFamily.Type.SOP:  return _build_sop(result)
		GNFamily.Type.DAT:  return _build_dat(result)
		GNFamily.Type.IMG:  return _build_img(result)
		GNFamily.Type.TOP:  return _build_top(result, inputs)
		_:                  return _build_extension(result, out_family)


## Per-port output routing — the cook engine calls this for each downstream wire.
func get_output_data(port_index: int) -> GNData:
	if port_index >= 0 and port_index < _output_data.size():
		return _output_data[port_index]
	return cached_output


func _build_chop(result: Dictionary) -> GNData:
	var out := GNChannelData.new()
	out.valid = true
	out.timestamp = current_frame
	if result.has("channels"):
		var channels: Dictionary = result["channels"]
		for cname in channels:
			out.channels[cname] = channels[cname]
		out.length = 0
		for cname in out.channels:
			var arr: PackedFloat32Array = out.channels[cname]
			if arr.size() > out.length:
				out.length = arr.size()
	if result.has("sample_rate"):
		out.sample_rate = result["sample_rate"]
	return out


func _build_sop(result: Dictionary) -> GNData:
	if not result.has("positions"):
		return null
	var positions: PackedVector3Array = result.get("positions", PackedVector3Array())
	if positions.is_empty():
		return null

	var st := SurfaceTool.new()
	var primitive: int = result.get("primitive", 3)
	st.begin(primitive as Mesh.PrimitiveType)

	var normals: PackedVector3Array = result.get("normals", PackedVector3Array())
	var uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())
	var colors: PackedColorArray = result.get("colors", PackedColorArray())
	var indices: PackedInt32Array = result.get("indices", PackedInt32Array())

	for i in range(positions.size()):
		if i < normals.size(): st.set_normal(normals[i])
		if i < uvs.size(): st.set_uv(uvs[i])
		if i < colors.size(): st.set_color(colors[i])
		st.add_vertex(positions[i])

	if not indices.is_empty():
		for idx_val in indices:
			st.add_index(idx_val)

	if normals.is_empty() and primitive == Mesh.PRIMITIVE_TRIANGLES:
		st.generate_normals()

	var out := GNGeoData.new()
	out.valid = true
	out.timestamp = current_frame
	out.set_from_surface_tool(st)
	return out


func _build_dat(result: Dictionary) -> GNData:
	var out := GNTableData.new()
	out.valid = true
	out.timestamp = current_frame
	if result.has("headers") and result.has("rows"):
		out.headers = result["headers"]
		out.rows = result["rows"]
	elif result.has("text"):
		out.text = result["text"]
	return out


func _build_img(result: Dictionary) -> GNData:
	if not result.has("image"):
		return null
	var out := GNImageData.new()
	out.valid = true
	out.timestamp = current_frame
	out.image = result["image"]
	return out


func _build_top(result: Dictionary, inputs: Array[GNData]) -> GNData:
	var res := Vector2i(512, 512)
	if parameters.has("resolution"):
		res = get_param_value("resolution")

	if result.has("shader_code"):
		var shader_code: String = result["shader_code"]
		_ensure_top_viewport(res)
		if _material != null:
			var shader := Shader.new()
			shader.code = shader_code
			_material.shader = shader
			if result.has("uniforms"):
				var uniforms: Dictionary = result["uniforms"]
				for uname in uniforms:
					_material.set_shader_parameter(uname, uniforms[uname])
			for i in range(input_ports.size()):
				if i < inputs.size() and inputs[i] is GNTextureData:
					_material.set_shader_parameter("u_state", inputs[i].texture)
		_cached_tex.resolution = res
		return _cached_tex
	elif result.has("image"):
		var img: Image = result["image"]
		if img != null:
			var tex := ImageTexture.create_from_image(img)
			if _cached_tex == null:
				_cached_tex = GNTextureData.new()
			_cached_tex.texture = tex
			_cached_tex.resolution = Vector2i(img.get_width(), img.get_height())
			_cached_tex.valid = true
			_cached_tex.timestamp = current_frame
			return _cached_tex
	return null


## Generic extension family output building — supports SDF and future extensions.
## Uses GNFamily.create_data_for_family() to instantiate the right data type,
## then sets properties from the result dictionary.
func _build_extension(result: Dictionary, family_id: int) -> GNData:
	var out: GNData = GNScriptHelper.create_data_for_family(family_id)
	if out == null:
		return null
	out.valid = true
	out.timestamp = current_frame
	# SDF: set sdf_tree and tree_hash if present
	if result.has("sdf_tree") and "sdf_tree" in out:
		out.set("sdf_tree", result["sdf_tree"])
		if result.has("tree_hash"):
			out.set("tree_hash", result["tree_hash"])
		else:
			out.set("tree_hash", hash(var_to_str(result["sdf_tree"])))
	return out


## Lazily creates viewport infrastructure for TOP shader rendering.
func _ensure_top_viewport(size: Vector2i) -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	add_child(_viewport)

	_material = ShaderMaterial.new()
	var canvas := ColorRect.new()
	canvas.name = "Canvas"
	canvas.material = _material
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(canvas)

	_cached_tex = GNTextureData.new()
	_cached_tex.texture = _viewport.get_texture()
	_cached_tex.viewport = _viewport
	_cached_tex.resolution = size


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## Delegates to base GNNode for data-type-aware preview.
## Shows warning text if there's an error, otherwise the data's preview.
func update_preview_control(control: Control) -> void:
	if not node_warning.is_empty():
		if control is Label:
			(control as Label).text = "ERR | %s" % node_warning.substr(0, 40)
		return
	super.update_preview_control(control)


# ═══════════════════════════════════════════════════════════════════════════════
# Shared Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _gather_user_params() -> Dictionary:
	var params := Dictionary()
	for pname in parameters:
		if pname in _SYSTEM_PARAMS:
			continue
		params[pname] = get_param_value(pname)
	for dp in _dynamic_params:
		if dp.get("type", "") == "vector3":
			var n: String = dp.get("name", "")
			params[n] = Vector3(
				params.get(n + "_x", 0.0),
				params.get(n + "_y", 0.0),
				params.get(n + "_z", 0.0))
	return params


func _trigger_build() -> void:
	var source: String = get_param_value("cpp_source")
	_auto_detect_class_name(source)
	if source.is_empty() or _cpp_class.is_empty():
		return
	_compile_error = ""
	node_warning = "Building C++..."
	_compiler.compile_async(id, source, _cpp_class, _on_compile_finished)


func _on_compile_finished(success: bool, output: String, lib_path: String) -> void:
	if success:
		_is_compiled = true
		_compile_error = ""
		node_warning = ""
		var gdext_path := lib_path.get_base_dir().path_join(
			"libuser_%s.gdextension" % id.replace("-", "_"))
		_processor = _reloader.load_and_instantiate(id, gdext_path, _cpp_class)
		if _processor != null:
			_processor.native_setup({"project_dir": ProjectSettings.globalize_path("res://")})
			_sync_ports_and_params()
			mark_dirty()
		else:
			node_warning = "Build OK but failed to load native class."
	else:
		_is_compiled = false
		_compile_error = output.substr(0, 200)
		node_warning = "C++ build failed."

	if _code_editor != null and _code_editor.visible:
		_code_editor.set_compile_status(success, output)


func _sync_ports_and_params() -> void:
	if _processor == null:
		return

	var port_defs: Array = _processor.get_port_definitions()
	if not port_defs.is_empty():
		_dynamic_ports = []
		input_ports.clear()
		output_ports.clear()
		for pd in port_defs:
			var pname: String = pd.get("name", "")
			var family_str: String = pd.get("family", "CHOP")
			var direction: String = pd.get("direction", "input")
			var required: bool = pd.get("required", false)
			var label: String = pd.get("label", "")
			var family_type: int = GNFamily.string_to_type(family_str)
			if direction == "input":
				add_input(pname, family_type, required, label)
			else:
				add_output(pname, family_type, label)
			_dynamic_ports.append(pd)

	var param_defs: Array = _processor.get_param_definitions()
	if not param_defs.is_empty():
		for dp in _dynamic_params:
			var dpname: String = dp.get("name", "")
			if parameters.has(dpname):
				parameters.erase(dpname)
		_dynamic_params = []

		for pd in param_defs:
			if pd.get("type", "") == "vector3":
				_add_vector3_params(pd)
				_dynamic_params.append(pd)
			else:
				var param := _make_param_from_def(pd)
				if param != null:
					add_parameter(param)
					_dynamic_params.append(pd)


func _make_param_from_def(pd: Dictionary) -> GNParameter:
	var pname: String = pd.get("name", "")
	var ptype: String = pd.get("type", "float")
	var plabel: String = pd.get("label", pname.capitalize())
	var pdesc: String = pd.get("description", "")
	match ptype:
		"float":
			return GNParameter.create_float(pname, pd.get("default", 0.0),
				pd.get("min", 0.0), pd.get("max", 1.0), pd.get("step", 0.01), plabel, pdesc)
		"int":
			return GNParameter.create_int(pname, pd.get("default", 0),
				pd.get("min", 0), pd.get("max", 100), plabel, pdesc)
		"bool":
			return GNParameter.create_bool(pname, pd.get("default", false), plabel, pdesc)
		"string":
			return GNParameter.create_string(pname, pd.get("default", ""), plabel, pdesc)
		"color":
			return GNParameter.create_color(pname, pd.get("default", Color.WHITE), plabel, pdesc)
		"enum":
			var options: PackedStringArray = pd.get("options", PackedStringArray())
			return GNParameter.create_enum(pname, options, pd.get("default", 0), plabel, pdesc)
		"vector2":
			return GNParameter.create_vector2(pname, pd.get("default", Vector2.ZERO), plabel, pdesc)
	return null


func _add_vector3_params(pd: Dictionary) -> void:
	var pname: String = pd.get("name", "")
	var plabel: String = pd.get("label", pname.capitalize())
	var pdesc: String = pd.get("description", "")
	var pmin = pd.get("min", 0.0)
	var pmax = pd.get("max", 1.0)
	var pstep = pd.get("step", 0.01)
	var v3: Vector3 = pd.get("default", Vector3.ZERO) if pd.get("default", null) is Vector3 else Vector3.ZERO
	add_parameter(GNParameter.create_float(pname + "_x", v3.x, pmin, pmax, pstep, plabel + " X", pdesc))
	add_parameter(GNParameter.create_float(pname + "_y", v3.y, pmin, pmax, pstep, plabel + " Y", pdesc))
	add_parameter(GNParameter.create_float(pname + "_z", v3.z, pmin, pmax, pstep, plabel + " Z", pdesc))


func _on_source_file_changed(_path: String) -> void:
	if get_param_value("auto_build"):
		_trigger_build()


func open_code_editor() -> void:
	if _code_editor == null:
		_code_editor = GNCppCodeEditor.new()
		add_child(_code_editor)
		_code_editor.code_committed.connect(_on_code_committed)
		_code_editor.build_requested.connect(_on_build_requested)
		_code_editor.check_requested.connect(_on_check_requested)
	_code_editor.open(self, get_param_value("cpp_source"))


func _on_code_committed(text: String) -> void:
	_auto_detect_class_name(text)
	set_param_value("cpp_source", text)
	mark_dirty()


func _on_build_requested(src: String) -> void:
	_auto_detect_class_name(src)
	set_param_value("cpp_source", src)
	_cpp_source = src
	_trigger_build()


func _on_check_requested(src: String) -> void:
	_auto_detect_class_name(src)
	set_param_value("cpp_source", src)
	_compiler.syntax_check_async(id, src, _on_check_finished)


func _on_check_finished(success: bool, output: String) -> void:
	if _code_editor != null and _code_editor.visible:
		_code_editor.set_compile_status(success, output)


## Extracts the C++ class name from source (e.g. "class Foo : public gn::GNUserNode")
## and updates _cpp_class.
func _auto_detect_class_name(source: String) -> void:
	var regex := RegEx.new()
	regex.compile("class\\s+(\\w+)\\s*:\\s*public\\s+gn::GNUserNode")
	var m := regex.search(source)
	if m != null:
		_cpp_class = m.get_string(1)


func _on_node_removed() -> void:
	if _reloader != null:
		_reloader.unload(id)
