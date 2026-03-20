class_name UserNativeSOP
extends GNSopBase
## User-written C++ SOP operator with hot-reload.
##
## Write native C++ geometry processing code that compiles in 2-8 seconds
## and hot-reloads without restarting GONODES. Runs at full native speed
## with WorkerThreadPool parallelism.
##
## Click "Edit C++ ↗" to open the code editor, or set the source via
## the "cpp_source" parameter.

const _DEFAULT_SOURCE := """#ifndef MY_SOP_H
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
		// Access input geometry
		if (inputs.size() == 0 || inputs[0].get_type() == Variant::NIL)
			return Dictionary();

		Dictionary in_geo = inputs[0];
		if (!in_geo.has("positions")) return Dictionary();

		PackedVector3Array positions = in_geo["positions"];
		float amp = parf(params, "amplitude", 1.0);
		float elapsed = parf(context, "elapsed", 0.0);

		// Process vertices at native C++ speed
		for (int i = 0; i < positions.size(); i++) {
			Vector3 &p = positions.ptrw()[i];
			p.y += sin(p.x * 3.0 + elapsed * 2.0) * amp;
		}

		return gn::make_sop_result(positions);
	}
};

#endif // MY_SOP_H
"""

var _processor: RefCounted = null
var _compiler: GNNativeCompiler = null
var _reloader: GNNativeReloader = null
var _file_watch: GNNativeFileWatch = null
var _code_editor: GNCppCodeEditor = null
var _cpp_source: String = ""
var _class_name_override: String = ""
var _compile_error: String = ""
var _is_compiled: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []


func _init() -> void:
	node_type = "usernativesop"
	node_description = "User C++ SOP — native-speed geometry processing with hot-reload."
	_compiler = GNNativeCompiler.new()
	_reloader = GNNativeReloader.new()
	_file_watch = GNNativeFileWatch.new()
	_file_watch.file_changed.connect(_on_source_file_changed)
	_cpp_source = _DEFAULT_SOURCE


func _init_ports() -> void:
	# Default ports — will be overridden when C++ is compiled
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Output geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("cpp_source", _DEFAULT_SOURCE,
		"C++ Source", "C++ source code for the native operator. Click 'Edit C++ ↗' to open the code editor."))
	add_parameter(GNParameter.create_string("cpp_class", "MyUserSOP",
		"Class Name", "C++ class name to register (must match the class in source)."))
	add_parameter(GNParameter.create_bool("auto_build", true,
		"Auto Build", "Automatically rebuild when source changes."))
	add_parameter(GNParameter.create_bool("time_dep", false,
		"Time Dependent", "Mark as time-dependent (recook every frame)."))


func _cook(inputs: Array[GNData]) -> GNData:
	# Update time dependency from parameter
	time_dependent = get_param_value("time_dep")

	var source: String = get_param_value("cpp_source")
	if source != _cpp_source:
		_cpp_source = source
		if get_param_value("auto_build"):
			_trigger_build()

	# If we have a native processor, use it
	if _processor != null:
		var result := _cook_native(inputs)
		if result != null:
			return result

	# No native processor — show status
	if not _compile_error.is_empty():
		node_warning = "C++ compile error: %s" % _compile_error
	elif not _is_compiled:
		node_warning = "C++ not compiled. Click 'Edit C++ ↗' and press Build."
	return null


func _cook_native(inputs: Array[GNData]) -> GNData:
	# Gather resolved parameters
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

	# Gather inputs as dictionaries
	var input_dicts := Array()
	for i in range(input_ports.size()):
		var in_data: GNData = _get_input_sop(inputs, i) if i < inputs.size() else null
		if in_data != null and in_data is GNGeoData:
			var geo: GNGeoData = in_data as GNGeoData
			var d := Dictionary()
			d["positions"] = geo.get_positions()
			d["normals"] = geo.get_normals()
			d["uvs"] = geo.get_uvs()
			d["vertex_count"] = geo.vertex_count
			input_dicts.append(d)
		else:
			input_dicts.append(null)

	# Build context
	var context := Dictionary()
	context["delta"] = current_delta
	context["elapsed"] = elapsed_time
	context["frame"] = current_frame

	# Call native cook
	var result: Dictionary = _processor.native_cook(params, input_dicts, context)
	if result.is_empty():
		return null

	# Build output GNGeoData from result dictionary
	var out := _prepare_geo()
	if result.has("positions"):
		var positions: PackedVector3Array = result.get("positions", PackedVector3Array())
		if positions.is_empty():
			return null

		var st := SurfaceTool.new()
		var primitive: int = result.get("primitive", 3)  # Mesh.PRIMITIVE_TRIANGLES
		st.begin(primitive as Mesh.PrimitiveType)

		var normals: PackedVector3Array = result.get("normals", PackedVector3Array())
		var uvs: PackedVector2Array = result.get("uvs", PackedVector2Array())
		var colors: PackedColorArray = result.get("colors", PackedColorArray())
		var indices: PackedInt32Array = result.get("indices", PackedInt32Array())

		for i in range(positions.size()):
			if i < normals.size():
				st.set_normal(normals[i])
			if i < uvs.size():
				st.set_uv(uvs[i])
			if i < colors.size():
				st.set_color(colors[i])
			st.add_vertex(positions[i])

		if not indices.is_empty():
			for idx_val in indices:
				st.add_index(idx_val)

		if normals.is_empty() and primitive == Mesh.PRIMITIVE_TRIANGLES:
			st.generate_normals()

		out.set_from_surface_tool(st)

	node_warning = ""
	return out


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

		# Hot-reload
		var cls_name: String = get_param_value("cpp_class")
		var gdext_path := lib_path.get_base_dir().path_join(
			"libuser_%s.gdextension" % id.replace("-", "_"))
		_processor = _reloader.load_and_instantiate(id, gdext_path, cls_name)

		if _processor != null:
			# Call setup
			var ctx := Dictionary()
			ctx["project_dir"] = ProjectSettings.globalize_path("res://")
			_processor.native_setup(ctx)

			# Sync dynamic ports and params from C++ definitions
			_sync_ports_and_params()
			mark_dirty()
		else:
			node_warning = "Build OK but failed to load native class."
	else:
		_is_compiled = false
		_compile_error = output.substr(0, 200)
		node_warning = "C++ build failed. Open code editor for details."

	# Update code editor if open
	if _code_editor != null and _code_editor.visible:
		_code_editor.set_compile_status(success, output)


func _sync_ports_and_params() -> void:
	if _processor == null:
		return

	# Sync ports from C++ definitions
	var port_defs: Array = _processor.get_port_definitions()
	if not port_defs.is_empty():
		_dynamic_ports = []
		input_ports.clear()
		output_ports.clear()
		for pd in port_defs:
			var pname: String = pd.get("name", "")
			var family_str: String = pd.get("family", "SOP")
			var direction: String = pd.get("direction", "input")
			var required: bool = pd.get("required", false)
			var label: String = pd.get("label", "")
			var family_type := _family_from_string(family_str)

			if direction == "input":
				add_input(pname, family_type, required, label)
			else:
				add_output(pname, family_type, label)
			_dynamic_ports.append(pd)

	# Sync params from C++ definitions (add as dynamic params)
	var param_defs: Array = _processor.get_param_definitions()
	if not param_defs.is_empty():
		# Remove old dynamic params
		for dp in _dynamic_params:
			var dpname: String = dp.get("name", "")
			if parameters.has(dpname):
				parameters.erase(dpname)
		_dynamic_params = []

		for pd in param_defs:
			var pname: String = pd.get("name", "")
			var ptype: String = pd.get("type", "float")
			var pdefault = pd.get("default", 0.0)
			var pmin = pd.get("min", 0.0)
			var pmax = pd.get("max", 1.0)
			var pstep = pd.get("step", 0.01)
			var plabel: String = pd.get("label", pname.capitalize())
			var pdesc: String = pd.get("description", "")

			var param: GNParameter = null
			match ptype:
				"float":
					param = GNParameter.create_float(pname, pdefault, pmin, pmax, pstep, plabel, pdesc)
				"int":
					param = GNParameter.create_int(pname, pdefault, pmin, pmax, plabel, pdesc)
				"bool":
					param = GNParameter.create_bool(pname, pdefault, plabel, pdesc)
				"string":
					param = GNParameter.create_string(pname, pdefault, plabel, pdesc)
				"color":
					param = GNParameter.create_color(pname, pdefault, plabel, pdesc)
				"enum":
					var options: PackedStringArray = pd.get("options", PackedStringArray())
					param = GNParameter.create_enum(pname, options, pdefault, plabel, pdesc)
				"vector2":
					param = GNParameter.create_vector2(pname, pdefault, plabel, pdesc)
				"vector3":
					# No create_vector3 — split into 3 float params
					var v3_default: Vector3 = pdefault if pdefault is Vector3 else Vector3.ZERO
					add_parameter(GNParameter.create_float(pname + "_x", v3_default.x, pmin, pmax, pstep, plabel + " X", pdesc))
					add_parameter(GNParameter.create_float(pname + "_y", v3_default.y, pmin, pmax, pstep, plabel + " Y", pdesc))
					param = GNParameter.create_float(pname + "_z", v3_default.z, pmin, pmax, pstep, plabel + " Z", pdesc)
			if param != null:
				add_parameter(param)
				_dynamic_params.append(pd)


func _family_from_string(s: String) -> GNFamily.Type:
	match s.to_upper():
		"SOP": return GNFamily.Type.SOP
		"CHOP": return GNFamily.Type.CHOP
		"TOP": return GNFamily.Type.TOP
		"IMG": return GNFamily.Type.IMG
		"DAT": return GNFamily.Type.DAT
		"MAT": return GNFamily.Type.MAT
		"POP": return GNFamily.Type.POP
		"VOL": return GNFamily.Type.VOL
	return GNFamily.Type.SOP


func _on_source_file_changed(_path: String) -> void:
	if get_param_value("auto_build"):
		_trigger_build()


# Called by the editor param row's "Edit C++ ↗" button
func open_code_editor() -> void:
	if _code_editor == null:
		_code_editor = GNCppCodeEditor.new()
		add_child(_code_editor)
		_code_editor.code_committed.connect(_on_code_committed)
		_code_editor.build_requested.connect(_on_build_from_editor)
	_code_editor.open(self, get_param_value("cpp_source"))


func _on_code_committed(text: String) -> void:
	set_param_value("cpp_source", text)
	mark_dirty()


func _on_build_from_editor(source: String) -> void:
	set_param_value("cpp_source", source)
	_cpp_source = source
	_trigger_build()


func _on_node_removed() -> void:
	if _reloader != null:
		_reloader.unload(id)
