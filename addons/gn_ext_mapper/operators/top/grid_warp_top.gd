class_name GridWarpTOP
extends GNTopBase
## NxM bilinear grid warp with per-point control parameters.
## Grid positions are passed directly as a vec2 uniform array — no CPU→GPU
## texture pipeline, no ImageTexture timing issues.

const MAX_GRID := 8  # Max cols/rows with per-point params (8×8 = 64 points)

var _last_cols: int = -1
var _last_rows: int = -1


func _init() -> void:
	node_type = "grid_warp"
	node_description = "Bilinear grid deformation with NxM control points."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_input("disp", GNFamily.Type.TOP, true, "Displacement map (RG = XY offset, optional)")
	add_output("out", GNFamily.Type.TOP, "Grid-warped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("grid_cols", 4, 2, MAX_GRID, "Grid Columns", "Number of control point columns"))
	add_parameter(GNParameter.create_int("grid_rows", 4, 2, MAX_GRID, "Grid Rows", "Number of control point rows"))
	add_parameter(GNParameter.create_float("amplitude", 1.0, -2.0, 2.0, 0.001, "Amplitude",
		"Global displacement multiplier applied to per-point offsets"))
	_rebuild_point_params(4, 4)
	_last_cols = 4
	_last_rows = 4


func _pre_cook(_delta: float) -> void:
	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	if cols != _last_cols or rows != _last_rows:
		_rebuild_point_params(cols, rows)
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

	# Optional displacement map from second input
	var disp_tex: GNTextureData = _get_input_top(inputs, 1)

	# Build the grid_points array (base UV + offset × amplitude)
	var points := _build_grid_points(cols, rows, amp, disp_tex)

	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/grid_warp.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		(_canvas as ColorRect).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("grid_cols", cols)
	_material.set_shader_parameter("grid_rows", rows)
	_material.set_shader_parameter("grid_points", points)

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Builds a flat PackedVector2Array of displaced UV positions for the shader.
func _build_grid_points(cols: int, rows: int, amp: float,
		disp_data: GNTextureData = null) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(cols * rows)

	# Read displacement texture on CPU if connected
	var disp_image: Image = null
	if disp_data != null and disp_data.texture != null:
		disp_image = disp_data.texture.get_image()

	for y in range(rows):
		for x in range(cols):
			var base_u: float = float(x) / float(cols - 1)
			var base_v: float = float(y) / float(rows - 1)

			var offset := Vector2.ZERO
			var pt_key := "pt_%d_%d" % [x, y]
			if parameters.has(pt_key + "_x"):
				offset.x = get_param_value(pt_key + "_x")
				offset.y = get_param_value(pt_key + "_y")

			# Displacement texture offsets (sampled at grid point position)
			if disp_image != null:
				var sx := clampi(int(base_u * float(disp_image.get_width() - 1)), 0, disp_image.get_width() - 1)
				var sy := clampi(int(base_v * float(disp_image.get_height() - 1)), 0, disp_image.get_height() - 1)
				var dc: Color = disp_image.get_pixel(sx, sy)
				offset.x += dc.r - 0.5
				offset.y += dc.g - 0.5

			points[y * cols + x] = Vector2(
				base_u + offset.x * amp,
				base_v + offset.y * amp)
	return points


## Dynamically adds/removes per-point offset params when grid size changes.
func _rebuild_point_params(cols: int, rows: int) -> void:
	# Remove old point params
	var to_remove: Array[String] = []
	for key in parameters:
		if key.begins_with("pt_"):
			to_remove.append(key)
	for key in to_remove:
		if parameters[key].value_changed.is_connected(_on_parameter_changed):
			parameters[key].value_changed.disconnect(_on_parameter_changed)
		if parameters[key].mode_changed.is_connected(_on_parameter_mode_changed):
			parameters[key].mode_changed.disconnect(_on_parameter_mode_changed)
		parameters.erase(key)

	for y in range(rows):
		for x in range(cols):
			var pt_key := "pt_%d_%d" % [x, y]
			var label := "Point (%d,%d)" % [x, y]
			var px := GNParameter.create_float(pt_key + "_x", 0.0, -1.0, 1.0, 0.001,
				"%s X" % label, "Horizontal offset for grid point (%d,%d)" % [x, y])
			var py := GNParameter.create_float(pt_key + "_y", 0.0, -1.0, 1.0, 0.001,
				"%s Y" % label, "Vertical offset for grid point (%d,%d)" % [x, y])
			add_parameter(px)
			add_parameter(py)
