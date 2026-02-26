class_name Shader_MAT
extends GNMatBase
## Custom shader material operator — wraps Godot's ShaderMaterial.
##
## Accepts shader code as a string parameter (or file path) and exposes
## up to 8 float uniforms plus color/texture inputs for full flexibility.
## Outputs a GNMaterialData containing a configured ShaderMaterial.
##
## Example usage:
##   • Toon shading, wireframe, hologram, dissolve, etc.
##   • Any visual effect expressible in Godot's shading language.

var _material: ShaderMaterial = null
var _shader: Shader = null
var _last_shader_code: String = ""


func _init() -> void:
	node_type = "shader"
	node_description = "Custom shader material (ShaderMaterial)."


func _init_ports() -> void:
	add_input("tex0", GNFamily.Type.TOP, false, "Texture uniform 0 (optional)")
	add_input("tex1", GNFamily.Type.TOP, false, "Texture uniform 1 (optional)")
	add_output("out", GNFamily.Type.MAT, "Shader material output")


func _init_parameters() -> void:
	# Shader source
	add_parameter(GNParameter.create_string("shader_code", _default_shader_code(),
		"Shader Code", "Godot shading language source"))
	add_parameter(GNParameter.create_file("shader_file", "",
		PackedStringArray(["*.gdshader"]),
		"Shader File", "Load shader from .gdshader file (overrides Shader Code if set)"))

	# Float uniforms — generic knobs that map to shader uniforms u0..u7
	add_parameter(GNParameter.create_float("u0", 0.0, null, null, 0.01, "Uniform 0", "Float uniform 'u0'"))
	add_parameter(GNParameter.create_float("u1", 0.0, null, null, 0.01, "Uniform 1", "Float uniform 'u1'"))
	add_parameter(GNParameter.create_float("u2", 0.0, null, null, 0.01, "Uniform 2", "Float uniform 'u2'"))
	add_parameter(GNParameter.create_float("u3", 0.0, null, null, 0.01, "Uniform 3", "Float uniform 'u3'"))
	add_parameter(GNParameter.create_float("u4", 0.0, null, null, 0.01, "Uniform 4", "Float uniform 'u4'"))
	add_parameter(GNParameter.create_float("u5", 0.0, null, null, 0.01, "Uniform 5", "Float uniform 'u5'"))
	add_parameter(GNParameter.create_float("u6", 0.0, null, null, 0.01, "Uniform 6", "Float uniform 'u6'"))
	add_parameter(GNParameter.create_float("u7", 0.0, null, null, 0.01, "Uniform 7", "Float uniform 'u7'"))

	# Color uniforms
	add_parameter(GNParameter.create_color("color0", Color.WHITE, "Color 0", "Color uniform 'color0'"))
	add_parameter(GNParameter.create_color("color1", Color.BLACK, "Color 1", "Color uniform 'color1'"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex0_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var tex1_in: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	# Lazy init
	if _material == null:
		_material = ShaderMaterial.new()
	if _shader == null:
		_shader = Shader.new()
		_material.shader = _shader

	# --- Determine shader source ---
	var shader_code: String = ""
	var shader_file: String = get_param_value("shader_file")

	if not shader_file.is_empty() and ResourceLoader.exists(shader_file):
		var loaded: Resource = ResourceLoader.load(shader_file)
		if loaded is Shader:
			# Use an externally loaded shader directly
			if _material.shader != loaded:
				_material.shader = loaded as Shader
				_shader = loaded as Shader
				_last_shader_code = ""
		else:
			GNLogger.error("Shader_MAT", "'%s' — file '%s' is not a valid Shader" % [id, shader_file])
	else:
		shader_code = get_param_value("shader_code")
		if shader_code != _last_shader_code:
			_shader.code = shader_code
			_last_shader_code = shader_code
			if _material.shader != _shader:
				_material.shader = _shader

	# --- Set float uniforms (u0..u7) ---
	for i in range(8):
		var u_name: String = "u%d" % i
		_material.set_shader_parameter(u_name, get_param_value(u_name))

	# --- Set color uniforms ---
	_material.set_shader_parameter("color0", get_param_value("color0"))
	_material.set_shader_parameter("color1", get_param_value("color1"))

	# --- Set texture uniforms ---
	if tex0_in != null and tex0_in.texture != null:
		_material.set_shader_parameter("tex0", tex0_in.texture)
	else:
		_material.set_shader_parameter("tex0", null)

	if tex1_in != null and tex1_in.texture != null:
		_material.set_shader_parameter("tex1", tex1_in.texture)
	else:
		_material.set_shader_parameter("tex1", null)

	# Build output
	var out := _prepare_output()
	out.material = _material
	var label_source: String = "file" if not shader_file.is_empty() else "code"
	out.material_label = "Shader (%s)" % label_source
	out.valid = true
	out.timestamp = current_frame
	return out


## Default shader code — a simple color shader with one uniform.
static func _default_shader_code() -> String:
	return """shader_type spatial;

uniform float u0 : hint_range(0.0, 1.0) = 0.5;
uniform vec4 color0 : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	ALBEDO = color0.rgb;
	ROUGHNESS = u0;
	METALLIC = 0.0;
}
"""
