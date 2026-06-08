class_name PythonSCRIPT
extends GNNode
## Python scripting node with per-family marshalling.
##
## Ports and parameters are defined by the Python code itself via
## `get_port_definitions()` and `get_param_definitions()`.  Use Presets
## in the code editor to load family-focused starting scripts (CHOP, SOP,
## DAT, IMG, TOP).


## Default Python source used when no preset has been loaded.
const _DEFAULT_SOURCE := """\"\"\"CHOP Template — Minimal channel generator.\"\"\"

from gonodes.chop import make_chop_result
from gonodes.params import output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "CHOP", label="Output channels"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("value", 0.0, -10.0, 10.0, 0.01, "Value"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    val = params.get("value", 0.0)
    channels = {"ch0": np.array([val], dtype=np.float32)}
    return make_chop_result(channels)
"""

## System parameter names (not forwarded to Python).
const _SYSTEM_PARAMS: PackedStringArray = ["py_source", "auto_reload", "time_dep"]

## Crash-safe diagnostic log path. Written via FileAccess so it survives a hard
## C++ abort() — unlike print() which is buffered over IPC and lost on crash.
const _DIAG_LOG := "user://python_diag.log"


# ═══════════════════════════════════════════════════════════════════════════════
# Instance State
# ═══════════════════════════════════════════════════════════════════════════════

var _processor: RefCounted = null
var _code_editor = null
var _py_source: String = ""
var _script_path: String = ""
var _load_error: String = ""
var _is_loaded: bool = false
var _dynamic_params: Array[Dictionary] = []
var _dynamic_ports: Array[Dictionary] = []
var _diag_started: bool = false

## Last cook duration in milliseconds (for preview display).
var _last_cook_ms: float = 0.0

## Per-port output data for multi-output support.
var _output_data: Array[GNData] = []

## TOP-specific: cached texture data for viewport-less texture output.
var _cached_tex: GNTextureData = null


func _init() -> void:
	family = GNFamily.Type.SCRIPT
	node_type = "pythonscript"
	node_description = "User Python SCRIPT — NumPy-powered processing with hot-reload."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.CHOP, "Output channels", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("py_source", _DEFAULT_SOURCE.strip_edges(),
		"Python Source", "Python source code. Click 'Edit Python ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_reload", true,
		"Auto Reload", "Automatically reload when source changes."))
	add_parameter(GNParameter.create_bool("time_dep", true,
		"Time Dependent", "Recook every frame."))


# ═══════════════════════════════════════════════════════════════════════════════
# Cook
# ═══════════════════════════════════════════════════════════════════════════════

func _cook(inputs: Array[GNData]) -> GNData:
	time_dependent = get_param_value("time_dep")

	if not _diag_started:
		_diag_started = true
		# Fresh log each session (truncate on first cook)
		var f := FileAccess.open(_DIAG_LOG, FileAccess.WRITE)
		if f:
			f.store_string("=== PythonSCRIPT diag log — node: %s ===\n" % id)
			f.close()
	_diag("cook start")
	_ensure_processor()
	_diag("_ensure_processor done — processor null: %s" % str(_processor == null))

	var source: String = get_param_value("py_source")
	if source != _py_source:
		_py_source = source
		if get_param_value("auto_reload"):
			_diag("source changed, calling _load_script")
			_load_script()
			_diag("_load_script returned — is_loaded: %s  error: '%s'" % [str(_is_loaded), _load_error])

	if _processor != null and _processor.is_loaded():
		var t0 := Time.get_ticks_usec()
		var result := _cook_python(inputs)
		_last_cook_ms = (Time.get_ticks_usec() - t0) / 1000.0
		return result

	if not _load_error.is_empty():
		node_warning = "Python error: %s" % _load_error.substr(0, 200)
	elif not _is_loaded:
		node_warning = "Python script not loaded. Click 'Edit Python ↗'."
	return null


func _cook_python(inputs: Array[GNData]) -> GNData:
	var params := _gather_user_params()
	var input_dicts := _marshal_inputs(inputs)

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

	node_warning = ""

	# Multi-output: {"outputs": [dict0, dict1, ...]}
	if result.has("outputs"):
		return _build_multi_output(result["outputs"])

	# Single-output (backwards-compatible)
	_output_data.clear()
	var data := _build_output_for_port(result, 0)
	if data != null:
		_output_data.append(data)
	return data


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
		var port_family: int = input_ports[i].family
		match port_family:
			GNFamily.Type.CHOP: input_dicts.append(_marshal_chop(in_data))
			GNFamily.Type.SOP:  input_dicts.append(_marshal_sop(in_data))
			GNFamily.Type.DAT:  input_dicts.append(_marshal_dat(in_data))
			GNFamily.Type.IMG:  input_dicts.append(_marshal_img(in_data))
			GNFamily.Type.TOP:  input_dicts.append(null)
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
		if dat.is_table:
			var rows_arr := []
			for ri in range(dat.num_rows()):
				rows_arr.append(Array(dat.get_row(ri)))
			return {"mode": "table",
					"header": Array(dat.get_headers()) if dat.has_header else [],
					"rows": rows_arr}
		else:
			return {"mode": "text", "text": dat.text}
	return null


func _marshal_img(data: GNData) -> Variant:
	if data is GNImageData:
		var img_data: GNImageData = data as GNImageData
		if img_data.image != null:
			return {"pixels": img_data.image.get_data(),
					"width": img_data.image.get_width(),
					"height": img_data.image.get_height(),
					"channels": 4, "format": "RGBA8"}
	return null


## Generic extension family marshalling — supports SDF and future extensions.
func _marshal_extension(data: GNData) -> Variant:
	# SDF data: carries an AST tree dictionary
	if "sdf_tree" in data and "tree_hash" in data:
		return {"sdf_tree": data.get("sdf_tree"), "tree_hash": data.get("tree_hash")}
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Output Building — dispatch by template
# ═══════════════════════════════════════════════════════════════════════════════

## Builds per-port output data from an array of result dicts.
func _build_multi_output(outputs_arr: Array) -> GNData:
	_output_data.clear()
	for i in range(mini(outputs_arr.size(), output_ports.size())):
		var port_result = outputs_arr[i]
		if port_result is Dictionary and not port_result.is_empty():
			_output_data.append(_build_output_for_port(port_result, i))
		else:
			_output_data.append(null)
	return _output_data[0] if not _output_data.is_empty() else null


## Builds typed GNData for a single port from its result dictionary.
func _build_output_for_port(result: Dictionary, port_index: int) -> GNData:
	if port_index < 0 or port_index >= output_ports.size():
		return null
	var out_family: int = output_ports[port_index].family
	match out_family:
		GNFamily.Type.CHOP: return _build_chop(result)
		GNFamily.Type.SOP:  return _build_sop(result)
		GNFamily.Type.DAT:  return _build_dat(result)
		GNFamily.Type.IMG:  return _build_img(result)
		GNFamily.Type.TOP:  return _build_top(result)
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
	var positions_flat: PackedFloat32Array = result.get("positions", PackedFloat32Array())
	if positions_flat.is_empty():
		return null

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

	var normals := PackedVector3Array()
	if result.has("normals"):
		var nf: PackedFloat32Array = result["normals"]
		normals.resize(nf.size() / 3)
		for vi in range(normals.size()):
			normals[vi] = Vector3(nf[vi * 3], nf[vi * 3 + 1], nf[vi * 3 + 2])

	var uvs := PackedVector2Array()
	if result.has("uvs"):
		var uf: PackedFloat32Array = result["uvs"]
		uvs.resize(uf.size() / 2)
		for vi in range(uvs.size()):
			uvs[vi] = Vector2(uf[vi * 2], uf[vi * 2 + 1])

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

	var out := GNGeoData.new()
	out.valid = true
	out.timestamp = current_frame
	out.set_from_surface_tool(st)
	return out


func _build_dat(result: Dictionary) -> GNData:
	var out := GNTableData.new()
	out.valid = true
	out.timestamp = current_frame
	var mode: String = result.get("mode", "table")
	if mode == "text":
		out.set_text(result.get("text", ""))
	else:
		if result.has("header"):
			var psa := PackedStringArray()
			for h in result.get("header", []):
				psa.append(str(h))
			out.set_headers(psa)
		if result.has("rows"):
			for row in result["rows"]:
				var row_psa := PackedStringArray()
				for cell in row:
					row_psa.append(str(cell))
				out.append_row(row_psa)
	return out


func _build_img(result: Dictionary) -> GNData:
	if not result.has("pixels"):
		return null
	var pixels: PackedByteArray = result.get("pixels", PackedByteArray())
	var w: int = result.get("width", 256)
	var h: int = result.get("height", 256)
	var fmt_str: String = result.get("format", "RGBA8")
	var img_fmt := Image.FORMAT_RGBA8 if fmt_str == "RGBA8" else Image.FORMAT_RGBAF
	var img := Image.create_from_data(w, h, false, img_fmt, pixels)
	var out := GNImageData.new()
	out.valid = true
	out.timestamp = current_frame
	out.set_image(img)
	return out


func _build_top(result: Dictionary) -> GNData:
	if not result.has("pixels"):
		return null
	var pixels: PackedByteArray = result.get("pixels", PackedByteArray())
	var w: int = result.get("width", 512)
	var h: int = result.get("height", 512)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pixels)
	var tex := ImageTexture.create_from_image(img)
	if _cached_tex == null:
		_cached_tex = GNTextureData.new()
	_cached_tex.texture = tex
	_cached_tex.resolution = Vector2i(w, h)
	_cached_tex.valid = true
	_cached_tex.timestamp = current_frame
	return _cached_tex


## Generic extension family output building — supports SDF and future extensions.
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


## Write msg to crash-safe file log AND to Godot output.
func _diag(msg: String) -> void:
	var full := "[PythonSCRIPT] %s" % msg
	print(full)
	var f := FileAccess.open(_DIAG_LOG, FileAccess.READ_WRITE)
	if f:
		f.seek_end(0)
		f.store_string(full + "\n")
		f.close()


func _ensure_processor() -> void:
	if _processor != null:
		return
	_diag("checking ClassDB for GNPythonProcessor")
	if not ClassDB.class_exists(&"GNPythonProcessor"):
		_load_error = "GNPythonRuntime not loaded. Check gn_python.gdextension."
		node_warning = _load_error
		_diag("ERROR: GNPythonProcessor not in ClassDB — extension failed to load")
		return
	_diag("GNPythonProcessor in ClassDB — calling ClassDB.instantiate...")
	_processor = ClassDB.instantiate(&"GNPythonProcessor")
	_diag("ClassDB.instantiate returned — null: %s" % str(_processor == null))


func _load_script() -> void:
	_ensure_processor()
	if _processor == null:
		return

	# Log toolchain state before any native call — file write survives C++ abort()
	var toolchain := ProjectSettings.globalize_path("res://addons/gn_ext_user_python/toolchain/python")
	_diag("toolchain path: " + toolchain)
	_diag("toolchain python3.dll present: %s" % str(FileAccess.file_exists(toolchain + "/python3.dll")))
	_diag("toolchain python310.dll present: %s" % str(FileAccess.file_exists(toolchain + "/python310.dll")))
	_diag("toolchain python310.zip present: %s" % str(FileAccess.file_exists(toolchain + "/python310.zip")))
	_diag("bin/win64/python310.dll present: %s" % str(FileAccess.file_exists(
			ProjectSettings.globalize_path("res://addons/gn_ext_user_python/bin/win64/python310.dll"))))

	var dir_path := "user://python_scripts/"
	DirAccess.make_dir_recursive_absolute(dir_path)
	_script_path = dir_path + id.replace("-", "_") + ".py"

	var fa := FileAccess.open(_script_path, FileAccess.WRITE)
	if fa == null:
		_load_error = "Cannot write script file."
		_diag("ERROR: Cannot write script file to " + _script_path)
		return
	fa.store_string(_py_source)
	fa.close()

	var global_path := ProjectSettings.globalize_path(_script_path)
	_diag("script written to: " + global_path)
	if _is_loaded:
		_diag(">>> calling reload_script() <<<")
		if not _processor.reload_script():
			_load_error = _processor.get_last_error()
			_diag("ERROR: reload_script failed: " + _load_error)
			return
		_diag("reload_script() returned OK")
	else:
		_diag(">>> calling load_script() — THIS IS WHERE Py_Initialize RUNS <<<")
		if not _processor.load_script(global_path):
			_load_error = _processor.get_last_error()
			_diag("ERROR: load_script failed: " + _load_error)
			return
		_diag("load_script() returned OK")

	_is_loaded = true
	_load_error = ""

	_diag(">>> calling python_setup() <<<")
	var ctx := {"project_dir": ProjectSettings.globalize_path("res://"), "node_name": name}
	_processor.python_setup(ctx)
	_diag("python_setup() returned — calling _sync_ports_and_params")
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
