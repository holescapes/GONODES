class_name BezierMapTOP
extends GNTopInteractiveBase
## Bicubic Bezier surface warp with 4x4 control point grid.

const _CP_NAMES: PackedStringArray = [
	"top_left", "top_cleft", "top_cright", "top_right",
	"umid_left", "umid_cleft", "umid_cright", "umid_right",
	"lmid_left", "lmid_cleft", "lmid_cright", "lmid_right",
	"bot_left", "bot_cleft", "bot_cright", "bot_right",
]

const _SHADER_NAMES: PackedStringArray = [
	"cp00", "cp10", "cp20", "cp30",
	"cp01", "cp11", "cp21", "cp31",
	"cp02", "cp12", "cp22", "cp32",
	"cp03", "cp13", "cp23", "cp33",
]


func _init() -> void:
	node_type = "bezier_map"
	node_description = "Smooth curved surface warp using a 4x4 Bezier control grid."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Bezier-warped texture", "Out")
	add_panel_output()


func _init_parameters() -> void:
	var defaults := [
		[0.0, 0.0], [0.333, 0.0], [0.667, 0.0], [1.0, 0.0],
		[0.0, 0.333], [0.333, 0.333], [0.667, 0.333], [1.0, 0.333],
		[0.0, 0.667], [0.333, 0.667], [0.667, 0.667], [1.0, 0.667],
		[0.0, 1.0], [0.333, 1.0], [0.667, 1.0], [1.0, 1.0],
	]
	var row_labels := ["Top", "Upper Mid", "Lower Mid", "Bottom"]
	var col_labels := ["Left", "Center-Left", "Center-Right", "Right"]
	for i in range(16):
		var n: String = _CP_NAMES[i]
		var d: Array = defaults[i]
		var row_idx: int = i / 4
		var col_idx: int = i % 4
		var label := "%s %s" % [row_labels[row_idx], col_labels[col_idx]]
		add_parameter(GNParameter.create_float(n + "_x", d[0], -1.0, 2.0, 0.001,
			"%s X" % label, "Horizontal position for control point row %d, col %d" % [row_idx, col_idx]))
		add_parameter(GNParameter.create_float(n + "_y", d[1], -1.0, 2.0, 0.001,
			"%s Y" % label, "Vertical position for control point row %d, col %d" % [row_idx, col_idx]))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BezierMapTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/bezier_warp.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)

	for i in range(16):
		var pt := Vector2(get_param_value(_CP_NAMES[i] + "_x"), get_param_value(_CP_NAMES[i] + "_y"))
		_material.set_shader_parameter(_SHADER_NAMES[i], pt)

	_sync_panel_from_params_if_live()
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _create_interactive_panel() -> GNInteractivePanel:
	var panel := MapperOverlay.new()
	panel.grid_cols = 4
	panel.grid_rows = 4
	panel.points.resize(16)
	panel.grab_radius_uv = 0.035
	return panel


func _sync_panel_from_params() -> void:
	if not is_instance_valid(_interactive_panel):
		return
	var panel: MapperOverlay = _interactive_panel as MapperOverlay
	if panel == null:
		return
	for i in range(16):
		var key: String = _CP_NAMES[i]
		panel.points[i] = Vector2(get_param_value(key + "_x"), get_param_value(key + "_y"))
	panel.queue_redraw()


func _sync_params_from_panel() -> void:
	if not is_instance_valid(_interactive_panel):
		return
	var panel: MapperOverlay = _interactive_panel as MapperOverlay
	if panel == null:
		return
	for i in range(16):
		var key: String = _CP_NAMES[i]
		if i < panel.points.size():
			set_param_value(key + "_x", panel.points[i].x)
			set_param_value(key + "_y", panel.points[i].y)
