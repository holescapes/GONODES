class_name PythonSCRIPT
extends GNNode
## Consolidated Python scripting node with per-family marshalling.
##
## A single unified node replaces the five per-family Python operators
## (UserPythonCHOP, UserPythonSOP, UserPythonDAT, UserPythonIMG, UserPythonTOP).
## A **Template** dropdown selects the target data family, which determines
## default Python source, port types, and input/output marshalling.

## Template choices — determines marshalling and default source.
enum Template { CHOP, SOP, DAT, IMG, TOP }

const _TEMPLATE_NAMES: PackedStringArray = ["CHOP", "SOP", "DAT", "IMG", "TOP"]


# ═══════════════════════════════════════════════════════════════════════════════
# Default Python Sources per Template
# ═══════════════════════════════════════════════════════════════════════════════

const _SRC_CHOP := """from gonodes.chop import make_chop_result, get_input_value
from gonodes.params import input_port, output_port, float_param, int_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "CHOP", label="Input channels"),
        output_port("out", "CHOP", label="Output channels"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("frequency", 1.0, 0.01, 100.0, 0.01, "Frequency", "Hz"),
        int_param("channels", 3, 1, 64, "Channels", "Number of output channels."),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    freq = params.get("frequency", 1.0)
    num_ch = int(params.get("channels", 3))
    t = context.get("elapsed", 0.0)

    channels = {}
    for i in range(num_ch):
        phase = i / num_ch * 2.0 * np.pi
        channels[f"ch{i}"] = np.array([np.sin(t * freq * 2.0 * np.pi + phase)],
                                       dtype=np.float32)

    return make_chop_result(channels)
"""


const _SRC_SOP := """from gonodes.sop import make_sop_result, get_input_positions
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


const _SRC_DAT := """from gonodes.dat import make_dat_result, get_input_table
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


const _SRC_IMG := """from gonodes.img import make_img_result, get_input_image
from gonodes.params import input_port, output_port, float_param
import numpy as np


def get_port_definitions():
    return {"ports": [
        input_port("in", "IMG", label="Input image"),
        output_port("out", "IMG", label="Output image"),
    ]}


def get_param_definitions():
    return {"params": [
        float_param("brightness", 1.0, 0.0, 3.0, 0.01, "Brightness"),
    ]}


def setup(me, context):
    pass


def cook(me, params, inputs, context):
    result = get_input_image(inputs, 0)
    if result is None:
        return {}

    pixels, w, h, c = result
    brightness = params.get("brightness", 1.0)

    # Vectorized brightness adjustment
    out = np.clip(pixels.astype(np.float32) * brightness, 0, 255).astype(np.uint8)

    return make_img_result(out, w, h, c)
"""


const _SRC_TOP := """from gonodes.top import make_top_result
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


const _SOURCES: Dictionary = {
	Template.CHOP: _SRC_CHOP,
	Template.SOP:  _SRC_SOP,
	Template.DAT:  _SRC_DAT,
	Template.IMG:  _SRC_IMG,
	Template.TOP:  _SRC_TOP,
}

## File suffix used when writing the Python source to disk.
const _SUFFIXES: Dictionary = {
	Template.CHOP: "_chop.py",
	Template.SOP:  "_sop.py",
	Template.DAT:  "_dat.py",
	Template.IMG:  "_img.py",
	Template.TOP:  "_top.py",
}

## Default port family per template.
const _PORT_FAMILIES: Dictionary = {
	Template.CHOP: GNFamily.Type.CHOP,
	Template.SOP:  GNFamily.Type.SOP,
	Template.DAT:  GNFamily.Type.DAT,
	Template.IMG:  GNFamily.Type.IMG,
	Template.TOP:  GNFamily.Type.TOP,
}

## System parameter names (not forwarded to Python).
const _SYSTEM_PARAMS: PackedStringArray = ["template", "py_source", "auto_reload", "time_dep"]


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
var _current_template: int = Template.CHOP

## Last cook duration in milliseconds (for preview display).
var _last_cook_ms: float = 0.0

## TOP-specific: cached texture data for viewport-less texture output.
var _cached_tex: GNTextureData = null


func _init() -> void:
	family = GNFamily.Type.SCRIPT
	node_type = "pythonscript"
	node_description = "User Python SCRIPT — NumPy-powered processing with hot-reload."


func _init_ports() -> void:
	_setup_ports_for_template(_current_template)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("template", _TEMPLATE_NAMES,
		Template.CHOP, "Template",
		"Target data family. Changing this replaces default source and port layout."))
	add_parameter(GNParameter.create_string("py_source", _SRC_CHOP,
		"Python Source", "Python source code. Click 'Edit Python ↗' to open the editor."))
	add_parameter(GNParameter.create_bool("auto_reload", true,
		"Auto Reload", "Automatically reload when source changes."))
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
	set_param_value("py_source", src)
	_py_source = ""       # Force reload on next cook
	_is_loaded = false
	_setup_ports_for_template(tpl)


func _setup_ports_for_template(tpl: int) -> void:
	input_ports.clear()
	output_ports.clear()
	var fam: int = _PORT_FAMILIES.get(tpl, GNFamily.Type.CHOP)
	if tpl != Template.TOP:
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

	_ensure_processor()

	var source: String = get_param_value("py_source")
	if source != _py_source:
		_py_source = source
		if get_param_value("auto_reload"):
			_load_script()

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
	return _build_output(result)


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
			Template.TOP:  input_dicts.append(null)
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


# ═══════════════════════════════════════════════════════════════════════════════
# Output Building — dispatch by template
# ═══════════════════════════════════════════════════════════════════════════════

func _build_output(result: Dictionary) -> GNData:
	match _current_template:
		Template.CHOP: return _build_chop(result)
		Template.SOP:  return _build_sop(result)
		Template.DAT:  return _build_dat(result)
		Template.IMG:  return _build_img(result)
		Template.TOP:  return _build_top(result)
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
	var suffix: String = _SUFFIXES.get(_current_template, "_chop.py")
	_script_path = dir_path + id.replace("-", "_") + suffix

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
