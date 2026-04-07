class_name TestCardTOP
extends GNTopBase
## Broadcast / projection-mapping calibration test card generator.
##
## Produces resolution-aware test patterns with SMPTE-style colour bars,
## calibration grid, centre crosshair, safe-area markers, corner brackets,
## and an on-screen resolution label.  Five card presets: Full, Grid Only,
## Color Bars Only, Grayscale, and RGBW quadrants.
##
## Designed for projection mapping — set the resolution to your projector's
## native resolution and the card scales all features accordingly.

const SHADER_PATH := "res://addons/gonodes/shaders/top/test_card.gdshader"


func _init() -> void:
	node_type = "testcard"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Test card texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1920, 1080),
		"Resolution", "Output resolution (match your projector / display)"))
	add_parameter(GNParameter.create_enum("card_type",
		PackedStringArray(["Full", "Grid Only", "Color Bars", "Grayscale", "RGBW"]),
		0, "Card Type", "Test card preset"))
	add_parameter(GNParameter.create_float("grid_cells", 16.0, 2.0, 64.0, 1.0,
		"Grid Cells", "Number of grid divisions on the long axis"))
	add_parameter(GNParameter.create_float("line_width", 1.5, 0.5, 5.0, 0.5,
		"Line Width", "Grid and marker line thickness (pixels)"))
	add_parameter(GNParameter.create_color("grid_color", Color(0.35, 0.35, 0.35, 1.0),
		"Grid Color", "Grid line colour"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.15, 0.15, 0.15, 1.0),
		"Background", "Background colour"))
	add_parameter(GNParameter.create_color("center_color", Color.WHITE,
		"Center Color", "Crosshair, corners, and label colour"))
	add_parameter(GNParameter.create_bool("show_grid", true,
		"Show Grid", "Draw calibration grid"))
	add_parameter(GNParameter.create_bool("show_center", true,
		"Show Center", "Draw centre crosshair and resolution label"))
	add_parameter(GNParameter.create_bool("show_color_bars", true,
		"Show Color Bars", "Draw SMPTE-style colour bars"))
	add_parameter(GNParameter.create_bool("show_grayscale", true,
		"Show Grayscale", "Draw grayscale ramp (bottom region in Full mode)"))
	add_parameter(GNParameter.create_bool("show_corners", true,
		"Show Corners", "Draw corner bracket markers"))
	add_parameter(GNParameter.create_bool("show_safe_area", true,
		"Show Safe Area", "Draw broadcast safe-area rectangle"))
	add_parameter(GNParameter.create_bool("show_circle", true,
		"Show Circle", "Draw inscribed circle"))
	add_parameter(GNParameter.create_float("safe_margin", 0.05, 0.01, 0.15, 0.01,
		"Safe Margin", "Safe-area margin as fraction of frame (0.05 = 5%)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport(SHADER_PATH, false, false, res)

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("resolution", Vector2(res))
	_material.set_shader_parameter("card_type", get_param_value("card_type"))
	_material.set_shader_parameter("grid_cells", get_param_value("grid_cells"))
	_material.set_shader_parameter("line_width", get_param_value("line_width"))

	var gc: Color = get_param_value("grid_color")
	_material.set_shader_parameter("grid_color", Vector4(gc.r, gc.g, gc.b, gc.a))
	var bg: Color = get_param_value("bg_color")
	_material.set_shader_parameter("bg_color", Vector4(bg.r, bg.g, bg.b, bg.a))
	var cc: Color = get_param_value("center_color")
	_material.set_shader_parameter("center_color", Vector4(cc.r, cc.g, cc.b, cc.a))

	_material.set_shader_parameter("show_grid", get_param_value("show_grid"))
	_material.set_shader_parameter("show_center", get_param_value("show_center"))
	_material.set_shader_parameter("show_color_bars", get_param_value("show_color_bars"))
	_material.set_shader_parameter("show_grayscale", get_param_value("show_grayscale"))
	_material.set_shader_parameter("show_corners", get_param_value("show_corners"))
	_material.set_shader_parameter("show_safe_area", get_param_value("show_safe_area"))
	_material.set_shader_parameter("show_circle", get_param_value("show_circle"))
	_material.set_shader_parameter("safe_margin", get_param_value("safe_margin"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
