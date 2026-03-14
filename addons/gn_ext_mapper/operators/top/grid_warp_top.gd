class_name GridWarpTOP
extends GNTopBase
## NxM bilinear grid warp using a control point grid texture.
## Each grid point defines a displaced UV position; interpolation is bilinear.

var _grid_image: Image = null
var _grid_texture: ImageTexture = null


func _init() -> void:
	node_type = "grid_warp"
	node_description = "Bilinear grid deformation with NxM control points."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Grid-warped texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("grid_cols", 4, 2, 32, "Grid Columns", "Number of control point columns"))
	add_parameter(GNParameter.create_int("grid_rows", 4, 2, 32, "Grid Rows", "Number of control point rows"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GridWarpTOP", "'%s' — no valid input" % id)
		return null

	var cols: int = get_param_value("grid_cols")
	var rows: int = get_param_value("grid_rows")
	var res: Vector2i = tex_in.resolution

	# Build control point grid texture (identity mapping by default)
	_build_grid_texture(cols, rows)

	_init_shader_viewport("res://addons/gn_ext_mapper/shaders/grid_warp.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("input_tex", tex_in.texture)
	_material.set_shader_parameter("grid_tex", _grid_texture)
	_material.set_shader_parameter("grid_cols", cols)
	_material.set_shader_parameter("grid_rows", rows)

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _build_grid_texture(cols: int, rows: int) -> void:
	if _grid_image != null and _grid_image.get_width() == cols and _grid_image.get_height() == rows:
		return
	# Create identity grid: each pixel RG = normalized position
	_grid_image = Image.create(cols, rows, false, Image.FORMAT_RGBAF)
	for y in range(rows):
		for x in range(cols):
			var u: float = float(x) / float(cols - 1)
			var v: float = float(y) / float(rows - 1)
			_grid_image.set_pixel(x, y, Color(u, v, 0.0, 1.0))
	_grid_texture = ImageTexture.create_from_image(_grid_image)
