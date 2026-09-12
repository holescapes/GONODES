class_name GridWarpTOP
extends GNTopInteractiveBase
## NxM bilinear grid warp with per-point control parameters.

const MAX_GRID := 8

var _last_cols: int = -1
var _last_rows: int = -1
var _grid_panel: GridWarpPanel = null


func _init() -> void:
	node_type = "grid_warp"
	node_description = "Bilinear grid deformation with NxM control points."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_input("disp", GNFamily.Type.TOP, true, "Displacement map (RG = XY offset, optional)", "Disp")
	add_output("out", GNFamily.Type.TOP, "Grid-warped texture", "Out")
	add_panel_output()


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("grid_cols", 4, 2, MAX_GRID, "Grid Columns", "Number of control point columns"))
	add_parameter(GNParameter.create_int("grid_rows", 4, 2, MAX_GRID, "Grid Rows", "Number of control point rows"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, -2.0, 2.0, 0.001, "Amplitude",
		"Global displacement multiplier applied to per-point offsets"))
	for y in range(MAX_GRID):
		for x in range(MAX_GRID):
			var pt_key := "pt_%d_%d" % [x, y]
			var label := "Point (%d,%d)" % [x, y]
			var px := GNParameter.create_float(pt_key + "_x", 0.0, -1.0, 1.0, 0.001,
				"%s X" % label, "Horizontal offset for grid point (%d,%d)" % [x, y])
			var py := GNParameter.create_float(pt_key + "_y", 0.0, -1.0, 1.0, 0.001,
				"%s Y" % label, "Vertical offset for grid point (%d,%d)" % [x, y])
			px.visible = (x < 4 and y < 4)
			py.visible = (x < 4 and y < 4)
			add_parameter(px)
			add_parameter(py)
	_last_cols = 4
	_last_rows = 4


func _pre_cook(_delta: float) -> void:
	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	if cols != _last_cols or rows != _last_rows:
		_update_point_visibility(cols, rows)
		_last_cols = cols
		_last_rows = rows
	super._pre_cook(_delta)


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GridWarpTOP", "'%s' — no valid input" % id)
		return null

	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	var amp: float = get_param_value("amplitude")
	var res: Vector2i = tex_in.resolution

	var disp_tex: GNTextureData = _get_input_top(inputs, 1)
	var offsets := _build_grid_offsets(cols, rows)

	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/grid_warp.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		(_canvas as ColorRect).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("grid_cols", cols)
	_material.set_shader_parameter("grid_rows", rows)
	_material.set_shader_parameter("amplitude", amp)
	_material.set_shader_parameter("grid_offsets", offsets)
	_material.set_shader_parameter("has_disp", disp_tex != null)
	if disp_tex != null:
		_material.set_shader_parameter("disp_tex", disp_tex.texture)

	_sync_panel_from_params()
	_cached_tex_data.resolution = res
	return _cached_tex_data


func _build_grid_offsets(cols: int, rows: int) -> PackedVector2Array:
	var offsets := PackedVector2Array()
	offsets.resize(cols * rows)
	for y in range(rows):
		for x in range(cols):
			var pt_key := "pt_%d_%d" % [x, y]
			offsets[y * cols + x] = Vector2(
				get_param_value(pt_key + "_x"),
				get_param_value(pt_key + "_y"))
	return offsets


func _build_overlay_points(cols: int, rows: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(cols * rows)
	for y in range(rows):
		for x in range(cols):
			var idx := y * cols + x
			var base_u := float(x) / float(cols - 1)
			var base_v := float(y) / float(rows - 1)
			var pt_key := "pt_%d_%d" % [x, y]
			points[idx] = Vector2(
				base_u + get_param_value(pt_key + "_x"),
				base_v + get_param_value(pt_key + "_y"))
	return points


func _update_point_visibility(cols: int, rows: int) -> void:
	for y in range(MAX_GRID):
		for x in range(MAX_GRID):
			var active: bool = (x < cols and y < rows)
			var pt_key := "pt_%d_%d" % [x, y]
			parameters[pt_key + "_x"].visible = active
			parameters[pt_key + "_y"].visible = active
	parameters_changed.emit(id)


func _create_interactive_panel() -> GNInteractivePanel:
	_grid_panel = GridWarpPanel.new()
	_grid_panel.grab_radius_uv = 0.04
	if not _grid_panel.point_offset_changed.is_connected(_on_grid_point_offset_changed):
		_grid_panel.point_offset_changed.connect(_on_grid_point_offset_changed)
	return _grid_panel


func _on_grid_point_offset_changed(grid_x: int, grid_y: int, offset: Vector2) -> void:
	var pt_key := "pt_%d_%d" % [grid_x, grid_y]
	set_param_value(pt_key + "_x", offset.x)
	set_param_value(pt_key + "_y", offset.y)


func _sync_panel_from_params() -> void:
	var panel: GridWarpPanel = _interactive_panel as GridWarpPanel
	if panel == null:
		return
	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	panel.grid_cols = cols
	panel.grid_rows = rows
	var points := _build_overlay_points(cols, rows)
	panel.points = points
	panel.queue_redraw()


func _sync_params_from_panel() -> void:
	var panel: GridWarpPanel = _interactive_panel as GridWarpPanel
	if panel == null:
		return
	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	for y in range(rows):
		for x in range(cols):
			var idx := y * cols + x
			if idx >= panel.points.size():
				continue
			var base_u: float = float(x) / float(cols - 1)
			var base_v: float = float(y) / float(rows - 1)
			var offset := panel.points[idx] - Vector2(base_u, base_v)
			var pt_key := "pt_%d_%d" % [x, y]
			set_param_value(pt_key + "_x", clampf(offset.x, -1.0, 1.0))
			set_param_value(pt_key + "_y", clampf(offset.y, -1.0, 1.0))
