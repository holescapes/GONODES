class_name QuadMapTOP
extends GNTopInteractiveBase
## Four-corner pin perspective warp using DLT homography.
## Interactive handles in the viewer or via the panel output → WindowOUT.

const _CORNER_KEYS: PackedStringArray = ["tl", "tr", "bl", "br"]


func _init() -> void:
	node_type = "quad_map"
	node_description = "Four-corner perspective warp for projection mapping surfaces."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Warped texture", "Out")
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


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("QuadMapTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/quad_warp.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		(_canvas as ColorRect).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("tl", Vector2(get_param_value("tl_x"), get_param_value("tl_y")))
	_material.set_shader_parameter("tr", Vector2(get_param_value("tr_x"), get_param_value("tr_y")))
	_material.set_shader_parameter("bl", Vector2(get_param_value("bl_x"), get_param_value("bl_y")))
	_material.set_shader_parameter("br", Vector2(get_param_value("br_x"), get_param_value("br_y")))

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
