class_name RampTOP
extends GNTopBase
## Generates a color gradient ramp (horizontal, vertical, radial, or circular).
## Source generator — no input required.

var _shader: Shader = null


func _init() -> void:
	node_type = "ramp"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated gradient texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_enum("type",
		PackedStringArray(["Horizontal", "Vertical", "Radial", "Circular"]), 0, "", "Gradient direction"))
	add_parameter(GNParameter.create_color("color_a", Color.BLACK, "", "Start color"))
	add_parameter(GNParameter.create_color("color_b", Color.WHITE, "", "End color"))
	add_parameter(GNParameter.create_vector2("center", Vector2(0.5, 0.5), "", "Center point for radial/circular"))
	add_parameter(GNParameter.create_float("phase", 0.0, null, null, 0.01, "", "Phase offset"))
	add_parameter(GNParameter.create_bool("repeat", false, "", "Repeat the gradient pattern"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	_init_shader_viewport("res://addons/gonodes/shaders/top/ramp.gdshader", false, false, res)
	var type_idx: int = get_param_value("type")
	var col_a: Color = get_param_value("color_a")
	var col_b: Color = get_param_value("color_b")
	var center_val: Vector2 = get_param_value("center")
	var phase_val: float = get_param_value("phase")
	var repeat_val: bool = get_param_value("repeat")

	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("ramp_type", type_idx)
	_material.set_shader_parameter("color_a", col_a)
	_material.set_shader_parameter("color_b", col_b)
	_material.set_shader_parameter("center", center_val)
	_material.set_shader_parameter("phase", phase_val)
	_material.set_shader_parameter("repeat_enabled", repeat_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data

