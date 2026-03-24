class_name WireframeMAT
extends GNMatBase
## Wireframe rendering material.
##
## Uses a ShaderMaterial with the spatial `wireframe` render mode to draw
## geometry edges only. Color and opacity are configurable.

var _material: ShaderMaterial = null
var _shader: Shader = null


func _init() -> void:
	node_type = "wireframe"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Wireframe material output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color", Color.GREEN, "Wire Color", "Wireframe line color"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01, "Alpha", "Wire opacity"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type spatial;\nrender_mode unshaded, wireframe;\nuniform vec4 wire_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);\nvoid fragment() {\n\tALBEDO = wire_color.rgb;\n\tALPHA = wire_color.a;\n}\n"

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = _shader

	var color: Color = get_param_value("color")
	color.a = get_param_value("alpha")
	_material.set_shader_parameter("wire_color", color)

	var out := _prepare_output()
	out.material = _material
	out.material_label = "Wireframe\n%s" % color
	out.valid = true
	out.timestamp = current_frame
	return out
