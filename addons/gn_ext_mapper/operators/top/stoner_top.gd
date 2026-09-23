class_name StonerTOP
extends GNTopInteractiveBase
## Keystone correction + grid subdivision + built-in test patterns.

const _CORNER_KEYS: PackedStringArray = ["tl", "tr", "bl", "br"]


func _init() -> void:
	node_type = "stoner"
	node_description = "Keystone correction with softedge blending and test patterns for projection surfaces."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to project", "In")
	add_output("out", GNFamily.Type.TOP, "Keystoned texture", "Out")
	add_panel_output()


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("tl_x", 0.0, -1.0, 2.0, 0.001, "Top-Left X", "Top-left corner X"))
	add_parameter(GNParameter.create_float("tl_y", 0.0, -1.0, 2.0, 0.001, "Top-Left Y", "Top-left corner Y"))
	add_parameter(GNParameter.create_float("tr_x", 1.0, -1.0, 2.0, 0.001, "Top-Right X", "Top-right corner X"))
	add_parameter(GNParameter.create_float("tr_y", 0.0, -1.0, 2.0, 0.001, "Top-Right Y", "Top-right corner Y"))
	add_parameter(GNParameter.create_float("bl_x", 0.0, -1.0, 2.0, 0.001, "Bottom-Left X", "Bottom-left corner X"))
	add_parameter(GNParameter.create_float("bl_y", 1.0, -1.0, 2.0, 0.001, "Bottom-Left Y", "Bottom-left corner Y"))
	add_parameter(GNParameter.create_float("br_x", 1.0, -1.0, 2.0, 0.001, "Bottom-Right X", "Bottom-right corner X"))
	add_parameter(GNParameter.create_float("br_y", 1.0, -1.0, 2.0, 0.001, "Bottom-Right Y", "Bottom-right corner Y"))
	add_parameter(GNParameter.create_int("grid_u", 1, 1, 16, "Grid U", "Horizontal subdivisions for curved surface correction"))
	add_parameter(GNParameter.create_int("grid_v", 1, 1, 16, "Grid V", "Vertical subdivisions for curved surface correction"))
	add_parameter(GNParameter.create_float("softedge_left", 0.0, 0.0, 0.5, 0.001, "Softedge Left", "Left edge blend width"))
	add_parameter(GNParameter.create_float("softedge_right", 0.0, 0.0, 0.5, 0.001, "Softedge Right", "Right edge blend width"))
	add_parameter(GNParameter.create_float("softedge_top", 0.0, 0.0, 0.5, 0.001, "Softedge Top", "Top edge blend width"))
	add_parameter(GNParameter.create_float("softedge_bottom", 0.0, 0.0, 0.5, 0.001, "Softedge Bottom", "Bottom edge blend width"))
	add_parameter(GNParameter.create_float("softedge_gamma", 2.2, 0.1, 5.0, 0.01, "Softedge Gamma", "Gamma correction for softedge luminance"))
	add_parameter(GNParameter.create_enum("test_pattern",
		PackedStringArray(["Off", "Grid", "Gradient"]), 0, "Test Pattern", "Built-in test pattern for alignment"))
	add_parameter(GNParameter.create_int("test_grid_lines", 8, 2, 32, "Grid Lines", "Number of grid lines in test pattern"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	var test_mode: int = get_param_value("test_pattern")
	if tex_in == null and test_mode == 0:
		GNLogger.warn("StonerTOP", "'%s' — no input and test pattern is off" % id)
		return null

	var res: Vector2i = tex_in.resolution if tex_in != null else Vector2i(1920, 1080)
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/stoner.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		(_canvas as ColorRect).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if tex_in != null:
		_material.set_shader_parameter("input_tex", tex_in.texture)

	_material.set_shader_parameter("tl", Vector2(get_param_value("tl_x"), get_param_value("tl_y")))
	_material.set_shader_parameter("tr", Vector2(get_param_value("tr_x"), get_param_value("tr_y")))
	_material.set_shader_parameter("bl", Vector2(get_param_value("bl_x"), get_param_value("bl_y")))
	_material.set_shader_parameter("br", Vector2(get_param_value("br_x"), get_param_value("br_y")))
	_material.set_shader_parameter("grid_u", get_param_value("grid_u"))
	_material.set_shader_parameter("grid_v", get_param_value("grid_v"))
	_material.set_shader_parameter("softedge_left", get_param_value("softedge_left"))
	_material.set_shader_parameter("softedge_right", get_param_value("softedge_right"))
	_material.set_shader_parameter("softedge_top", get_param_value("softedge_top"))
	_material.set_shader_parameter("softedge_bottom", get_param_value("softedge_bottom"))
	_material.set_shader_parameter("softedge_gamma", get_param_value("softedge_gamma"))
	_material.set_shader_parameter("show_test_pattern", test_mode)
	_material.set_shader_parameter("test_grid_lines", get_param_value("test_grid_lines"))

	_sync_panel_from_params_if_live()
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _create_interactive_panel() -> GNInteractivePanel:
	var panel := MapperOverlay.new()
	panel.draw_quad_outline = true
	panel.points.resize(4)
	panel.grab_radius_uv = 0.04
	return panel


func _sync_panel_from_params() -> void:
	if not is_instance_valid(_interactive_panel):
		return
	var panel: MapperOverlay = _interactive_panel as MapperOverlay
	if panel == null:
		return
	for i in range(4):
		var key: String = _CORNER_KEYS[i]
		panel.points[i] = Vector2(get_param_value(key + "_x"), get_param_value(key + "_y"))
	panel.queue_redraw()


func _sync_params_from_panel() -> void:
	if not is_instance_valid(_interactive_panel):
		return
	var panel: MapperOverlay = _interactive_panel as MapperOverlay
	if panel == null:
		return
	for i in range(4):
		var key: String = _CORNER_KEYS[i]
		if i < panel.points.size():
			set_param_value(key + "_x", panel.points[i].x)
			set_param_value(key + "_y", panel.points[i].y)
