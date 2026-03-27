class_name NativeSCRIPT
extends GNNode
## Consolidated Native C++ scripting node with per-family marshalling.
##
## A single unified node replaces the five per-family Native operators
## (UserNativeCHOP, UserNativeSOP, UserNativeDAT, UserNativeIMG, UserNativeTOP).
## A **Template** dropdown selects the target data family, which determines
## default C++ source, port types, and input/output marshalling.

## Template choices — determines marshalling and default source.
enum Template { CHOP, SOP, DAT, IMG, TOP }

const _TEMPLATE_NAMES: PackedStringArray = ["CHOP", "SOP", "DAT", "IMG", "TOP"]


# ═══════════════════════════════════════════════════════════════════════════════
# Default C++ Sources per Template
# ═══════════════════════════════════════════════════════════════════════════════

const _SRC_CHOP := """#ifndef MY_CHOP_H
#define MY_CHOP_H

#include <gn_user_node.h>
#include <gn_user_chop.h>

using namespace godot;

class MyUserCHOP : public gn::GNUserNode {
	GDCLASS(MyUserCHOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "my_user_chop"; }
	String get_node_description() const override { return "My custom CHOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "CHOP"; in0["direction"] = "input";
		in0["required"] = false; in0["label"] = "Input channels";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "CHOP"; out0["direction"] = "output";
		out0["label"] = "Output channels";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		Dictionary p;
		p["name"] = "frequency"; p["type"] = "float";
		p["default"] = 1.0; p["min"] = 0.01; p["max"] = 100.0; p["step"] = 0.01;
		p["label"] = "Frequency"; p["description"] = "Oscillation frequency in Hz.";
		params.push_back(p);
		Dictionary p2;
		p2["name"] = "channels"; p2["type"] = "int";
		p2["default"] = 3; p2["min"] = 1; p2["max"] = 64;
		p2["label"] = "Channels"; p2["description"] = "Number of output channels.";
		params.push_back(p2);
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float freq = parf(params, "frequency", 1.0);
		int num_ch = pari(params, "channels", 3);
		float elapsed = parf(context, "elapsed", 0.0);

		Dictionary channels;
		for (int i = 0; i < num_ch; i++) {
			PackedFloat32Array arr;
			float phase = float(i) / float(num_ch) * Math_TAU;
			arr.push_back(sin(elapsed * freq * Math_TAU + phase));
			channels[String("ch") + String::num_int64(i)] = arr;
		}

		return gn::make_chop_result(channels);
	}
};

#endif // MY_CHOP_H
"""


const _SRC_SOP := """#ifndef MY_SOP_H
#define MY_SOP_H

#include <gn_user_node.h>
#include <gn_user_sop.h>

using namespace godot;

class MyUserSOP : public gn::GNUserNode {
	GDCLASS(MyUserSOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "my_user_sop"; }
	String get_node_description() const override { return "My custom SOP."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "SOP"; in0["direction"] = "input";
		in0["required"] = false; in0["label"] = "Input geometry";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "SOP"; out0["direction"] = "output";
		out0["label"] = "Output geometry";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		Dictionary p;
		p["name"] = "amplitude"; p["type"] = "float";
		p["default"] = 1.0; p["min"] = 0.0; p["max"] = 10.0; p["step"] = 0.01;
		p["label"] = "Amplitude"; p["description"] = "Deformation strength.";
		params.push_back(p);
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		if (inputs.size() == 0 || inputs[0].get_type() == Variant::NIL)
			return Dictionary();

		Dictionary in_geo = inputs[0];
		if (!in_geo.has("positions")) return Dictionary();

		PackedVector3Array positions = in_geo["positions"];
		float amp = parf(params, "amplitude", 1.0);
		float elapsed = parf(context, "elapsed", 0.0);

		for (int i = 0; i < positions.size(); i++) {
			Vector3 &p = positions.ptrw()[i];
			p.y += sin(p.x * 3.0 + elapsed * 2.0) * amp;
		}

		return gn::make_sop_result(positions);
	}
};

#endif // MY_SOP_H
"""


const _SRC_DAT := """#ifndef MY_DAT_H
#define MY_DAT_H

#include <gn_user_node.h>
#include <gn_user_dat.h>

using namespace godot;

class MyUserDAT : public gn::GNUserNode {
	GDCLASS(MyUserDAT, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "my_user_dat"; }
	String get_node_description() const override { return "My custom DAT — table/text processing."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "DAT"; in0["direction"] = "input";
		in0["required"] = false; in0["label"] = "Input table/text";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "DAT"; out0["direction"] = "output";
		out0["label"] = "Output table/text";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		Dictionary p;
		p["name"] = "rows"; p["type"] = "int";
		p["default"] = 10; p["min"] = 1; p["max"] = 10000;
		p["label"] = "Rows"; p["description"] = "Number of rows to generate.";
		params.push_back(p);
		Dictionary p2;
		p2["name"] = "columns"; p2["type"] = "int";
		p2["default"] = 3; p2["min"] = 1; p2["max"] = 256;
		p2["label"] = "Columns"; p2["description"] = "Number of columns.";
		params.push_back(p2);
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		int num_rows = pari(params, "rows", 10);
		int num_cols = pari(params, "columns", 3);
		float elapsed = parf(context, "elapsed", 0.0);

		PackedStringArray headers;
		for (int c = 0; c < num_cols; c++) {
			headers.push_back(String("col") + String::num_int64(c));
		}

		Array rows;
		for (int r = 0; r < num_rows; r++) {
			PackedStringArray row;
			for (int c = 0; c < num_cols; c++) {
				float val = sin(elapsed + float(r * num_cols + c) * 0.1);
				row.push_back(String::num(val, 3));
			}
			rows.push_back(row);
		}

		return gn::make_dat_table(headers, rows);
	}
};

#endif // MY_DAT_H
"""


const _SRC_IMG := """#ifndef MY_IMG_H
#define MY_IMG_H

#include <gn_user_node.h>
#include <gn_user_img.h>

using namespace godot;

class MyUserIMG : public gn::GNUserNode {
	GDCLASS(MyUserIMG, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "my_user_img"; }
	String get_node_description() const override { return "My custom IMG — per-pixel processing."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "IMG"; in0["direction"] = "input";
		in0["required"] = true; in0["label"] = "Input image";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "IMG"; out0["direction"] = "output";
		out0["label"] = "Output image";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		Dictionary p;
		p["name"] = "brightness"; p["type"] = "float";
		p["default"] = 1.0; p["min"] = 0.0; p["max"] = 4.0; p["step"] = 0.01;
		p["label"] = "Brightness"; p["description"] = "Brightness multiplier.";
		params.push_back(p);
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float brightness = parf(params, "brightness", 1.0);

		Ref<Image> img = gn::get_input_image(inputs, 0);
		if (img.is_null()) {
			return Dictionary();
		}

		Ref<Image> out = gn::create_like(img);
		int w = img->get_width();
		int h = img->get_height();

		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				Color c = img->get_pixel(x, y);
				c.r = CLAMP(c.r * brightness, 0.0f, 1.0f);
				c.g = CLAMP(c.g * brightness, 0.0f, 1.0f);
				c.b = CLAMP(c.b * brightness, 0.0f, 1.0f);
				out->set_pixel(x, y, c);
			}
		}

		return gn::make_img_result(out);
	}
};

#endif // MY_IMG_H
"""


const _SRC_TOP := """#ifndef MY_TOP_H
#define MY_TOP_H

#include <gn_user_node.h>
#include <gn_user_top.h>

using namespace godot;

class MyUserTOP : public gn::GNUserNode {
	GDCLASS(MyUserTOP, gn::GNUserNode)

protected:
	static void _bind_methods() {
		gn::GNUserNode::_bind_methods();
	}

public:
	String get_node_type() const override { return "my_user_top"; }
	String get_node_description() const override { return "My custom TOP — GPU shader."; }

	Array get_port_definitions() const override {
		Array ports;
		Dictionary in0;
		in0["name"] = "in"; in0["family"] = "TOP"; in0["direction"] = "input";
		in0["required"] = false; in0["label"] = "Input texture";
		ports.push_back(in0);
		Dictionary out0;
		out0["name"] = "out"; out0["family"] = "TOP"; out0["direction"] = "output";
		out0["label"] = "Output texture";
		ports.push_back(out0);
		return ports;
	}

	Array get_param_definitions() const override {
		Array params;
		Dictionary p;
		p["name"] = "speed"; p["type"] = "float";
		p["default"] = 1.0; p["min"] = 0.0; p["max"] = 10.0; p["step"] = 0.01;
		p["label"] = "Speed"; p["description"] = "Animation speed.";
		params.push_back(p);
		Dictionary p2;
		p2["name"] = "color"; p2["type"] = "color";
		p2["default"] = Color(0.2, 0.6, 1.0, 1.0);
		p2["label"] = "Color"; p2["description"] = "Primary color.";
		params.push_back(p2);
		return params;
	}

	Dictionary native_cook(const Dictionary &params, const Array &inputs,
	                        const Dictionary &context) override {
		float speed = parf(params, "speed", 1.0);
		Color color = params.get("color", Color(0.2, 0.6, 1.0, 1.0));
		float elapsed = parf(context, "elapsed", 0.0);

		String shader = R"(
shader_type canvas_item;
uniform float u_time;
uniform vec4 u_color : source_color;

void fragment() {
	vec2 uv = UV;
	float d = length(uv - 0.5);
	float ring = smoothstep(0.3, 0.28, d) - smoothstep(0.25, 0.23, d);
	float angle = atan(uv.y - 0.5, uv.x - 0.5);
	float wave = sin(angle * 6.0 + u_time * 3.0) * 0.5 + 0.5;
	COLOR = vec4(u_color.rgb * ring * wave, 1.0);
}
)";

		Dictionary uniforms;
		uniforms["u_time"] = elapsed * speed;
		uniforms["u_color"] = color;

		return gn::make_top_shader_result(shader, uniforms);
	}
};

#endif // MY_TOP_H
"""


const _SOURCES: Dictionary = {
	Template.CHOP: _SRC_CHOP,
	Template.SOP:  _SRC_SOP,
	Template.DAT:  _SRC_DAT,
	Template.IMG:  _SRC_IMG,
	Template.TOP:  _SRC_TOP,
}

## Default class names per template.
const _CLASS_NAMES: Dictionary = {
	Template.CHOP: "MyUserCHOP",
	Template.SOP:  "MyUserSOP",
	Template.DAT:  "MyUserDAT",
	Template.IMG:  "MyUserIMG",
	Template.TOP:  "MyUserTOP",
}

## Default port family per template.
const _PORT_FAMILIES: Dictionary = {
	Template.CHOP: GNFamily.Type.CHOP,
	Template.SOP:  GNFamily.Type.SOP,
	Template.DAT:  GNFamily.Type.DAT,
	Template.IMG:  GNFamily.Type.IMG,
	Template.TOP:  GNFamily.Type.TOP,
}

## System parameter names (not forwarded to native code).
const _SYSTEM_PARAMS: PackedStringArray = ["template", "cpp_source", "cpp_class", "auto_build", "time_dep"]


# ═══════════════════════════════════════════════════════════════════════════════
# Instance State
# ═══════════════════════════════════════════════════════════════════════════════

var _processor: RefCounted = null
var _compiler: GNNativeCompiler = null
var _reloader: GNNativeReloader = null
var _file_watch: GNNativeFileWatch = null
var _code_editor: GNCppCodeEditor = null
var _cpp_source: String = ""
var _compile_error: String = ""
var _is_compiled: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []
var _current_template: int = Template.CHOP

## Last cook duration in milliseconds (for preview display).
var _last_cook_ms: float = 0.0

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
	_cpp_source = _SRC_CHOP


func _init_ports() -> void:
	_setup_ports_for_template(_current_template)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("template", _TEMPLATE_NAMES,
		Template.CHOP, "Template",
		"Target data family. Changing this replaces default source and port layout."))
	add_parameter(GNParameter.create_string("cpp_source", _SRC_CHOP,
		"C++ Source", "C++ source code. Click 'Edit C++ ↗' to open the editor."))
	add_parameter(GNParameter.create_string("cpp_class", "MyUserCHOP",
		"Class Name", "C++ class name to register."))
	add_parameter(GNParameter.create_bool("auto_build", true,
		"Auto Build", "Automatically rebuild on source change."))
	add_parameter(GNParameter.create_bool("time_dep", true,
		"Time Dependent", "Recook every frame."))


## Called by the registry when the cfg entry has a `preset=` key.
func apply_preset(preset_name: String) -> void:
	var tpl: int = Template.CHOP
	match preset_name.to_lower():
		"chop": tpl = Template.CHOP
		"sop":  tpl = Template.SOP
		"dat":  tpl = Template.DAT
		"img":  tpl = Template.IMG
		"top":  tpl = Template.TOP
	_apply_template(tpl)


func _apply_template(tpl: int) -> void:
	_current_template = tpl
	set_param_value("template", tpl)
	var src: String = _SOURCES.get(tpl, _SRC_CHOP)
	var cls: String = _CLASS_NAMES.get(tpl, "MyUserCHOP")
	set_param_value("cpp_source", src)
	set_param_value("cpp_class", cls)
	_cpp_source = ""       # Force reload on next cook
	_is_compiled = false
	_processor = null
	_setup_ports_for_template(tpl)


func _setup_ports_for_template(tpl: int) -> void:
	input_ports.clear()
	output_ports.clear()
	var fam: int = _PORT_FAMILIES.get(tpl, GNFamily.Type.CHOP)
	add_input("in", fam, false, "Input")
	add_output("out", fam, "Output")


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")

	# Detect template change
	var tpl_val: int = get_param_value("template")
	if tpl_val != _current_template:
		_apply_template(tpl_val)

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
	return _build_output(result, inputs)


# ═══════════════════════════════════════════════════════════════════════════════
# Input Marshalling — dispatch by template
# ═══════════════════════════════════════════════════════════════════════════════

func _marshal_inputs(inputs: Array[GNData]) -> Array:
	var input_dicts := Array()
	for i in range(input_ports.size()):
		var in_data: GNData = inputs[i] if i < inputs.size() else null
		if in_data == null:
			input_dicts.append(null)
			continue
		match _current_template:
			Template.CHOP: input_dicts.append(_marshal_chop(in_data))
			Template.SOP:  input_dicts.append(_marshal_sop(in_data))
			Template.DAT:  input_dicts.append(_marshal_dat(in_data))
			Template.IMG:  input_dicts.append(_marshal_img(in_data))
			Template.TOP:  input_dicts.append({"family": "TOP"})
			_:             input_dicts.append(null)
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


# ═══════════════════════════════════════════════════════════════════════════════
# Output Building — dispatch by template
# ═══════════════════════════════════════════════════════════════════════════════

func _build_output(result: Dictionary, inputs: Array[GNData]) -> GNData:
	match _current_template:
		Template.CHOP: return _build_chop(result)
		Template.SOP:  return _build_sop(result)
		Template.DAT:  return _build_dat(result)
		Template.IMG:  return _build_img(result)
		Template.TOP:  return _build_top(result, inputs)
	return null


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


## Lazily creates viewport infrastructure for TOP-template shader rendering.
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
	canvas.anchors_preset = Control.PRESET_FULL_RECT
	_viewport.add_child(canvas)

	_cached_tex = GNTextureData.new()
	_cached_tex.texture = _viewport.get_texture()
	_cached_tex.viewport = _viewport
	_cached_tex.resolution = size


# ═══════════════════════════════════════════════════════════════════════════════
# Preview
# ═══════════════════════════════════════════════════════════════════════════════

## SCRIPT nodes show cook time + status, not data preview.
func update_preview_control(control: Control) -> void:
	if not control is Label:
		return
	var label := control as Label
	if not node_warning.is_empty():
		label.text = "ERR | %s" % node_warning.substr(0, 40)
	elif _last_cook_ms > 0.0:
		label.text = "%.1fms | OK" % _last_cook_ms
	else:
		label.text = ""


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
	var cls_name: String = get_param_value("cpp_class")
	if source.is_empty() or cls_name.is_empty():
		return
	_compile_error = ""
	node_warning = "Building C++..."
	_compiler.compile_async(id, source, cls_name, _on_compile_finished)


func _on_compile_finished(success: bool, output: String, lib_path: String) -> void:
	if success:
		_is_compiled = true
		_compile_error = ""
		node_warning = ""
		var cls_name: String = get_param_value("cpp_class")
		var gdext_path := lib_path.get_base_dir().path_join(
			"libuser_%s.gdextension" % id.replace("-", "_"))
		_processor = _reloader.load_and_instantiate(id, gdext_path, cls_name)
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
		_code_editor.code_committed.connect(func(text): set_param_value("cpp_source", text); mark_dirty())
		_code_editor.build_requested.connect(func(src): set_param_value("cpp_source", src); _cpp_source = src; _trigger_build())
	_code_editor.open(self, get_param_value("cpp_source"))


func _on_node_removed() -> void:
	if _reloader != null:
		_reloader.unload(id)
