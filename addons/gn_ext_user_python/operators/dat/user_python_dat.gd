class_name UserPythonDAT
extends GNDatBase
## User-written Python DAT operator with hot-reload.
## Write Python table/text data processing code.

const _DEFAULT_SOURCE := """from gonodes.dat import make_dat_result, get_input_table
from gonodes.params import input_port, output_port, string_param


def get_port_definitions():
    return {"ports": [
        input_port("in", "DAT", label="Input table"),
        output_port("out", "DAT", label="Output table"),
    ]}


def get_param_definitions():
    return {"params": [
        string_param("filter", "", "Filter", "Only keep rows containing this string."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    header, rows = get_input_table(inputs, 0)
    filter_str = params.get("filter", "")

    if rows and filter_str:
        rows = [r for r in rows if any(filter_str in str(c) for c in r)]

    return make_dat_result(rows=rows, header=header)
"""

var _processor: RefCounted = null
var _code_editor = null
var _py_source: String = ""
var _script_path: String = ""
var _load_error: String = ""
var _is_loaded: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []


func _init() -> void:
	node_type = "userpythondat"
	node_description = "User Python DAT — data table/text processing with hot-reload."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.DAT, false, "Input table")
	add_output("out", GNFamily.Type.DAT, "Output table")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("py_source", _DEFAULT_SOURCE,
		"Python Source", "Python source code. Click 'Edit Python ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_reload", true,
		"Auto Reload", "Automatically reload when source changes."))
	add_parameter(GNParameter.create_bool("time_dep", false,
		"Time Dependent", "Recook every frame."))


func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")
	_ensure_processor()

	var source: String = get_param_value("py_source")
	if source != _py_source:
		_py_source = source
		if get_param_value("auto_reload"):
			_load_script()

	if _processor != null and _processor.is_loaded():
		return _cook_python(inputs)

	if not _load_error.is_empty():
		node_warning = "Python error: %s" % _load_error.substr(0, 200)
	elif not _is_loaded:
		node_warning = "Python script not loaded. Click 'Edit Python ↗'."
	return null


func _cook_python(inputs: Array[GNData]) -> GNData:
	var params := _gather_user_params()

	var input_dicts := Array()
	for i in range(input_ports.size()):
		var in_data: GNData = _get_input_dat(inputs, i) if i < inputs.size() else null
		if in_data != null and in_data is GNTableData:
			var dat: GNTableData = in_data as GNTableData
			var d := Dictionary()
			if dat.is_table:
				d["mode"] = "table"
				d["header"] = Array(dat.get_headers()) if dat.has_header else []
				var rows_arr := []
				for ri in range(dat.num_rows()):
					rows_arr.append(Array(dat.get_row(ri)))
				d["rows"] = rows_arr
			else:
				d["mode"] = "text"
				d["text"] = dat.text
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

	# Build output DAT data
	var out := _prepare_table(true)
	var mode: String = result.get("mode", "table")
	if mode == "text":
		out.set_text(result.get("text", ""))
	else:
		if result.has("header"):
			var hdr = result.get("header", [])
			var psa := PackedStringArray()
			for h in hdr:
				psa.append(str(h))
			out.set_headers(psa)
		if result.has("rows"):
			for row in result["rows"]:
				var row_psa := PackedStringArray()
				for cell in row:
					row_psa.append(str(cell))
				out.append_row(row_psa)

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

	var dir_path := "user://python_scripts/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	_script_path = dir_path + id.replace("-", "_") + "_dat.py"

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

	var ctx := {"project_dir": ProjectSettings.globalize_path("res://"), "node_name": name}
	_processor.python_setup(ctx)
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
			var family_str: String = pd.get("family", "DAT")
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
	return GNFamily.Type.DAT


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
	pass
