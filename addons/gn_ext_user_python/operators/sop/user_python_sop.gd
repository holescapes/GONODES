class_name UserPythonSOP
extends GNSopBase
## User-written Python SOP operator with hot-reload.
##
## Write Python geometry processing code using NumPy. Scripts are loaded
## directly — no compilation required. Changes apply instantly on reload.
##
## Click "Edit Python ↗" to open the code editor.

const _DEFAULT_SOURCE := """from gonodes.sop import make_sop_result, get_input_positions
from gonodes.params import input_port, output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "SOP", label="Input geometry"),
        output_port("out", "SOP", label="Output geometry"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("amplitude", 1.0, 0.0, 10.0, 0.01, "Amplitude", "Deformation strength."),
    ]}


def setup(me, context):
    pass  # Called once at load and on reload


def cook(me, params, inputs, context):
    positions = get_input_positions(inputs, 0)
    if positions is None:
        return {}

    amp = params.get("amplitude", 1.0)
    t = context.get("elapsed", 0.0)

    # Vectorized vertex deformation with NumPy
    positions[:, 1] += np.sin(positions[:, 0] * 3.0 + t * 2.0) * amp

    return make_sop_result(positions)
"""

var _processor: RefCounted = null
var _code_editor = null  # GNPythonCodeEditor
var _py_source: String = ""
var _script_path: String = ""
var _load_error: String = ""
var _is_loaded: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []


func _init() -> void:
	node_type = "userpythonsop"
	node_description = "User Python SOP — NumPy-powered geometry processing with hot-reload."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.SOP, false, "Input geometry")
	add_output("out", GNFamily.Type.SOP, "Output geometry")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("py_source", _DEFAULT_SOURCE,
		"Python Source", "Python source code. Click 'Edit Python ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_reload", true,
		"Auto Reload", "Automatically reload when source changes."))
	add_parameter(GNParameter.create_bool("time_dep", false,
		"Time Dependent", "Recook every frame."))


func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")

	# Ensure processor exists
	_ensure_processor()

	var source: String = get_param_value("py_source")
	if source != _py_source:
		_py_source = source
		if get_param_value("auto_reload"):
			_load_script()

	if _processor != null and _processor.is_loaded():
		var result := _cook_python(inputs)
		if result != null:
			return result

	if not _load_error.is_empty():
		node_warning = "Python error: %s" % _load_error.substr(0, 200)
	elif not _is_loaded:
		node_warning = "Python script not loaded. Click 'Edit Python ↗'."
	return null


func _cook_python(inputs: Array[GNData]) -> GNData:
	var params := _gather_user_params()

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

	var context := {
		"delta": current_delta, "elapsed": elapsed_time,
		"frame": current_frame, "node_name": name,
	}

	var result: Dictionary = _processor.python_cook(params, input_dicts, context)
	if result.is_empty():
		return null

	if result.has("error"):
		_load_error = result["error"]
		node_warning = "Python cook error: %s" % _load_error.substr(0, 200)
		return null

	# Build output GNGeoData from result dictionary
	var out := _prepare_geo()
	if result.has("positions"):
		var positions_flat: PackedFloat32Array = result.get("positions", PackedFloat32Array())
		if positions_flat.is_empty():
			return null

		# Convert flat float32 array to PackedVector3Array
		var positions := PackedVector3Array()
		positions.resize(positions_flat.size() / 3)
		for vi in range(positions.size()):
			positions[vi] = Vector3(
				positions_flat[vi * 3],
				positions_flat[vi * 3 + 1],
				positions_flat[vi * 3 + 2])

		var st := SurfaceTool.new()
		var primitive: int = result.get("primitive", 3)
		st.begin(primitive as Mesh.PrimitiveType)

		# Normals
		var normals := PackedVector3Array()
		if result.has("normals"):
			var nf: PackedFloat32Array = result["normals"]
			normals.resize(nf.size() / 3)
			for vi in range(normals.size()):
				normals[vi] = Vector3(nf[vi * 3], nf[vi * 3 + 1], nf[vi * 3 + 2])

		# UVs
		var uvs := PackedVector2Array()
		if result.has("uvs"):
			var uf: PackedFloat32Array = result["uvs"]
			uvs.resize(uf.size() / 2)
			for vi in range(uvs.size()):
				uvs[vi] = Vector2(uf[vi * 2], uf[vi * 2 + 1])

		# Colors
		var colors := PackedColorArray()
		if result.has("colors"):
			var cf: PackedFloat32Array = result["colors"]
			colors.resize(cf.size() / 4)
			for vi in range(colors.size()):
				colors[vi] = Color(cf[vi * 4], cf[vi * 4 + 1], cf[vi * 4 + 2], cf[vi * 4 + 3])

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

		out.set_from_surface_tool(st)

	node_warning = ""
	return out


func _gather_user_params() -> Dictionary:
	var params := Dictionary()
	for pname in parameters:
		if pname in ["py_source", "auto_reload", "time_dep"]:
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


func _ensure_processor() -> void:
	if _processor != null:
		return
	if not ClassDB.class_exists(&"GNPythonProcessor"):
		node_warning = "GNPythonRuntime not loaded. Check gn_python.gdextension."
		return
	_processor = ClassDB.instantiate(&"GNPythonProcessor")


func _load_script() -> void:
	_ensure_processor()
	if _processor == null:
		return

	# Write source to temp file
	var dir_path := "user://python_scripts/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	_script_path = dir_path + id.replace("-", "_") + "_sop.py"

	var fa := FileAccess.open(_script_path, FileAccess.WRITE)
	if fa == null:
		_load_error = "Cannot write script file."
		return
	fa.store_string(_py_source)
	fa.close()

	var global_path := ProjectSettings.globalize_path(_script_path)
	if _is_loaded:
		if not _processor.reload_script():
			_load_error = _processor.get_last_error()
			return
	else:
		if not _processor.load_script(global_path):
			_load_error = _processor.get_last_error()
			return

	_is_loaded = true
	_load_error = ""

	# Call setup
	var ctx := {"project_dir": ProjectSettings.globalize_path("res://"), "node_name": name}
	_processor.python_setup(ctx)

	# Sync ports and params from Python definitions
	_sync_ports_and_params()
	mark_dirty()


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

	var param_defs: Array = _processor.get_param_definitions()
	if not param_defs.is_empty():
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

			var p: GNParameter = null
			match ptype:
				"float":
					p = GNParameter.create_float(pname, pdefault, pmin, pmax, pstep, plabel, pdesc)
				"int":
					p = GNParameter.create_int(pname, pdefault, pmin, pmax, plabel, pdesc)
				"bool":
					p = GNParameter.create_bool(pname, pdefault, plabel, pdesc)
				"string":
					p = GNParameter.create_string(pname, pdefault, plabel, pdesc)
				"color":
					p = GNParameter.create_color(pname, pdefault, plabel, pdesc)
				"enum":
					var options: PackedStringArray = pd.get("options", PackedStringArray())
					p = GNParameter.create_enum(pname, options, pdefault, plabel, pdesc)
				"vector2":
					p = GNParameter.create_vector2(pname, pdefault, plabel, pdesc)
				"vector3":
					var v3 = pdefault if pdefault is Vector3 else Vector3.ZERO
					add_parameter(GNParameter.create_float(pname + "_x", v3.x, pmin, pmax, pstep, plabel + " X", pdesc))
					add_parameter(GNParameter.create_float(pname + "_y", v3.y, pmin, pmax, pstep, plabel + " Y", pdesc))
					p = GNParameter.create_float(pname + "_z", v3.z, pmin, pmax, pstep, plabel + " Z", pdesc)
			if p != null:
				add_parameter(p)
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


func open_code_editor() -> void:
	if _code_editor == null:
		_code_editor = GNPythonCodeEditor.new()
		add_child(_code_editor)
		_code_editor.code_committed.connect(_on_code_committed)
		_code_editor.reload_requested.connect(_on_reload_from_editor)
	_code_editor.open(self, get_param_value("py_source"))


func _on_code_committed(text: String) -> void:
	set_param_value("py_source", text)
	mark_dirty()


func _on_reload_from_editor(source: String) -> void:
	set_param_value("py_source", source)
	_py_source = source
	_load_script()


func _on_node_removed() -> void:
	if _processor != null and _processor.is_loaded():
		# Release the Python module handle
		pass
