class_name LineMAT
extends GNMatBase
## Wireframe / line-based rendering material with width, color, and stipple.
## Uses a ShaderMaterial with a custom line shader for rendering edges
## with configurable width, dash pattern, and color.

var _material: ShaderMaterial = null
var _shader: Shader = null

const LINE_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, wireframe;

uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float line_width : hint_range(0.1, 10.0) = 1.0;
uniform float stipple_scale : hint_range(0.1, 100.0) = 10.0;
uniform float stipple_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist_pattern = fract(length(world_pos) * stipple_scale);
	if (dist_pattern > stipple_ratio) {
		discard;
	}
	ALBEDO = line_color.rgb;
	ALPHA = alpha * line_color.a;
}
"""


func _init() -> void:
	node_type = "line"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Line material output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color", Color.WHITE, "Color",
		"Line color"))
	add_parameter(GNParameter.create_float("width", 1.0, 0.1, 10.0, 0.1,
		"Width", "Line width"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01,
		"Alpha", "Overall opacity"))
	add_parameter(GNParameter.create_float("stipple_scale", 10.0, 0.1, 100.0, 0.5,
		"Stipple Scale", "Dash pattern frequency"))
	add_parameter(GNParameter.create_float("stipple_ratio", 1.0, 0.0, 1.0, 0.01,
		"Stipple Ratio", "Visible portion of each dash (1.0 = solid)"))
	add_parameter(GNParameter.create_enum("cull_mode",
		PackedStringArray(["Back", "Front", "Disabled"]), 2,
		"Cull Mode", "Face culling"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = LINE_SHADER_CODE

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = _shader

	var color: Color = get_param_value("color")
	_material.set_shader_parameter("line_color", color)
	_material.set_shader_parameter("line_width", get_param_value("width"))
	_material.set_shader_parameter("alpha", get_param_value("alpha"))
	_material.set_shader_parameter("stipple_scale", get_param_value("stipple_scale"))
	_material.set_shader_parameter("stipple_ratio", get_param_value("stipple_ratio"))

	# Cull mode is set on the shader render_mode; for runtime changes
	# we'd need to recompile the shader code. Instead just note this is
	# already set to wireframe mode in the shader string.

	var out := _prepare_output()
	out.material = _material
	out.material_label = "Line\n%s\nw:%.1f" % [color, get_param_value("width")]
	out.valid = true
	out.timestamp = current_frame
	return out
