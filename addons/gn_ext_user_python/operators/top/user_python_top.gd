class_name UserPythonTOP
extends GNTopBase
## User-written Python TOP operator with hot-reload.
## Write Python texture generation code using NumPy for CPU-side pixel work.

const _DEFAULT_SOURCE := """from gonodes.top import make_top_result
from gonodes.params import output_port, int_param, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        output_port("out", "TOP", label="Output texture"),
    ]}


def get_param_definitions():
    return {"params": [
        int_param("width", 512, 1, 4096, "Width"),
        int_param("height", 512, 1, 4096, "Height"),
        float_param("speed", 1.0, 0.0, 10.0, 0.01, "Speed"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    w = int(params.get("width", 512))
    h = int(params.get("height", 512))
    speed = params.get("speed", 1.0)
    t = context.get("elapsed", 0.0)

    # Generate a gradient pattern
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]

    r = np.sin(x * 6.28 + t * speed) * 0.5 + 0.5
    g = np.sin(y * 6.28 + t * speed * 0.7) * 0.5 + 0.5
    b = np.sin((x + y) * 3.14 + t * speed * 1.3) * 0.5 + 0.5

    pixels = np.zeros((h, w, 4), dtype=np.uint8)
    pixels[:, :, 0] = (r * 255).astype(np.uint8)
    pixels[:, :, 1] = (g * 255).astype(np.uint8)
    pixels[:, :, 2] = (b * 255).astype(np.uint8)
    pixels[:, :, 3] = 255

    return make_top_result(pixels, w, h)
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
	node_type = "userpythontop"
	node_description = "User Python TOP — NumPy-powered texture generation with hot-reload."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Output texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("py_source", _DEFAULT_SOURCE,
		"Python Source", "Python source code. Click 'Edit Python ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_reload", true,
		"Auto Reload", "Automatically reload when source changes."))
	add_parameter(GNParameter.create_bool("time_dep", true,
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
	# TOP may have inputs — pass texture data if available
	for i in range(input_ports.size()):
		input_dicts.append(null)  # TOP inputs handled via viewport, not direct pixel data

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

	# Build output texture from pixel data
	if result.has("pixels"):
		var pixels: PackedByteArray = result.get("pixels", PackedByteArray())
		var w: int = result.get("width", 512)
		var h: int = result.get("height", 512)
		var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pixels)
		var tex := ImageTexture.create_from_image(img)
		_cached_tex_data.texture = tex
		_cached_tex_data.resolution = Vector2i(w, h)

	node_warning = ""
	return _cached_tex_data


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
	_script_path = dir_path + id.replace("-", "_") + "_top.py"

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
			var family_str: String = pd.get("family", "TOP")
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
	return GNFamily.Type.TOP


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
