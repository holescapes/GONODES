class_name PointSpriteMAT
extends GNMatBase
## Renders geometry vertices as point sprites.
##
## Uses a ShaderMaterial with POINT_SIZE in the vertex shader so each vertex
## is drawn as a screen-space square. Accepts an optional TOP input for a
## sprite texture applied via POINT_COORD.

var _material: ShaderMaterial = null
var _shader: Shader = null


func _init() -> void:
	node_type = "point_sprite"
	node_description = "Renders vertices as point sprites."


func _init_ports() -> void:
	add_input("tex_in", GNFamily.Type.TOP, false, "Sprite texture (optional)", "Texture")
	add_output("out", GNFamily.Type.MAT, "Point sprite material output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color", Color.WHITE, "Color", "Point color"))
	add_parameter(GNParameter.create_float("point_size", 4.0, 1.0, 64.0, 0.5, "Point Size", "Size of each point sprite in pixels"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	if _shader == null:
		_shader = Shader.new()
		_shader.code = "shader_type spatial;\nrender_mode unshaded, vertex_lighting;\nuniform vec4 sprite_color : source_color = vec4(1.0);\nuniform float point_size : hint_range(1.0, 64.0) = 4.0;\nuniform sampler2D sprite_tex : hint_default_white;\nuniform bool use_texture = false;\nvoid vertex() {\n\tPOINT_SIZE = point_size;\n}\nvoid fragment() {\n\tvec4 c = sprite_color;\n\tif (use_texture) {\n\t\tc *= texture(sprite_tex, POINT_COORD);\n\t}\n\tALBEDO = c.rgb;\n\tALPHA = c.a;\n}\n"

	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = _shader

	var color: Color = get_param_value("color")
	_material.set_shader_parameter("sprite_color", color)
	_material.set_shader_parameter("point_size", get_param_value("point_size"))

	if tex_in != null and tex_in.texture != null:
		_material.set_shader_parameter("sprite_tex", tex_in.texture)
		_material.set_shader_parameter("use_texture", true)
	else:
		_material.set_shader_parameter("use_texture", false)

	var out := _prepare_output()
	out.material = _material
	out.material_label = "Points\nSize:%.1f" % get_param_value("point_size")
	out.valid = true
	out.timestamp = current_frame
	return out
