class_name UserNativeDAT
extends GNDatBase
## User-written C++ DAT operator with hot-reload.
## Write native C++ table/text processing at full speed.

const _DEFAULT_SOURCE := """#ifndef MY_DAT_H
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


func _init() -> void:
	node_type = "usernativedat"
	node_description = "User C++ DAT — native-speed table/text processing with hot-reload."
	_compiler = GNNativeCompiler.new()
	_reloader = GNNativeReloader.new()
	_file_watch = GNNativeFileWatch.new()
	_file_watch.file_changed.connect(_on_source_file_changed)
	_cpp_source = _DEFAULT_SOURCE


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table/text")
	add_output("out", GNFamily.Type.DAT, "Output table/text")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("cpp_source", _DEFAULT_SOURCE,
		"C++ Source", "C++ source code for this DAT operator."))
	add_parameter(GNParameter.create_string("cpp_class", "MyUserDAT",
		"Class Name", "C++ class name to register."))
	add_parameter(GNParameter.create_bool("auto_build", true,
		"Auto Build", "Automatically rebuild on source change."))
	add_parameter(GNParameter.create_bool("time_dep", true,
		"Time Dependent", "Recook every frame."))


func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")

	var source: String = get_param_value("cpp_source")
	if source != _cpp_source:
		_cpp_source = source
		if get_param_value("auto_build"):
			_trigger_build()

	if _processor != null:
		return _cook_native(inputs)

	if not _compile_error.is_empty():
		node_warning = "C++ compile error: %s" % _compile_error
	elif not _is_compiled:
		node_warning = "C++ not compiled. Click 'Edit C++ ↗' and press Build."
	return null


func _cook_native(inputs: Array[GNData]) -> GNData:
	var params := _gather_user_params()

	var input_dicts := Array()
	for i in range(input_ports.size()):
		var in_data: GNTableData = _get_input_dat(inputs, i) if i < inputs.size() else null
		if in_data != null:
			var d := Dictionary()
			d["headers"] = in_data.headers.duplicate()
			d["rows"] = in_data.rows.duplicate()
			d["text"] = in_data.text if in_data.text != null else ""
			input_dicts.append(d)
		else:
			input_dicts.append(null)

	var context := {"delta": current_delta, "elapsed": elapsed_time, "frame": current_frame}
	var result: Dictionary = _processor.native_cook(params, input_dicts, context)
	if result.is_empty():
		return null

	var out := _prepare_table()
	if result.has("headers") and result.has("rows"):
		out.headers = result["headers"]
		out.rows = result["rows"]
	elif result.has("text"):
		out.text = result["text"]

	node_warning = ""
	return out


func _gather_user_params() -> Dictionary:
	var params := Dictionary()
	for pname in parameters:
		if pname in ["cpp_source", "cpp_class", "auto_build", "time_dep"]:
			continue
		params[pname] = get_param_value(pname)
	# Reassemble vector3 params split into _x/_y/_z back into Vector3
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
		input_ports.clear()
		output_ports.clear()
		for pd in port_defs:
			var direction: String = pd.get("direction", "input")
			var family_type := _family_str_to_type(pd.get("family", "DAT"))
			if direction == "input":
				add_input(pd.get("name", ""), family_type, pd.get("required", false), pd.get("label", ""))
			else:
				add_output(pd.get("name", ""), family_type, pd.get("label", ""))

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


func _family_str_to_type(s: String) -> GNFamily.Type:
	match s.to_upper():
		"SOP": return GNFamily.Type.SOP
		"CHOP": return GNFamily.Type.CHOP
		"TOP": return GNFamily.Type.TOP
		"IMG": return GNFamily.Type.IMG
		"DAT": return GNFamily.Type.DAT
		"MAT": return GNFamily.Type.MAT
	return GNFamily.Type.DAT


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
