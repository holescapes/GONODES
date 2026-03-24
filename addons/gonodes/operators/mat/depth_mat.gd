class_name DepthMAT
extends GNMatBase
## Visualizes scene depth as grayscale.
##
## Applies a ShaderMaterial that linearizes fragment depth between configurable
## near/far planes and outputs a grayscale value. Optionally inverts the
## mapping so near is black and far is white.

var _material: ShaderMaterial = null
var _shader: Shader = null


func _init() -> void:
	node_type = "depth"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.MAT, "Depth material output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("near_val", 0.1, 0.001, 100.0, 0.01, "Near", "Near depth (white)"))
	add_parameter(GNParameter.create_float("far_val", 100.0, 1.0, 10000.0, 1.0, "Far", "Far depth (black)"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", "Invert depth (near=black, far=white)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type spatial;\nrender_mode unshaded;\nuniform float near_val : hint_range(0.001, 100.0) = 0.1;\nuniform float far_val : hint_range(1.0, 10000.0) = 100.0;\nuniform bool invert = false;\nvoid fragment() {\n\tfloat depth = FRAGCOORD.z;\n\tfloat linear_depth = (2.0 * near_val) / (far_val + near_val - depth * (far_val - near_val));\n\tfloat d = clamp(linear_depth, 0.0, 1.0);\n\tif (invert) {\n\t\td = 1.0 - d;\n\t}\n\tALBEDO = vec3(d);\n}\n"

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = _shader

	_material.set_shader_parameter("near_val", get_param_value("near_val"))
	_material.set_shader_parameter("far_val", get_param_value("far_val"))
	_material.set_shader_parameter("invert", get_param_value("invert"))

	var out := _prepare_output()
	out.material = _material
	out.material_label = "Depth\nN:%.2f F:%.1f" % [get_param_value("near_val"), get_param_value("far_val")]
	out.valid = true
	out.timestamp = current_frame
	return out
