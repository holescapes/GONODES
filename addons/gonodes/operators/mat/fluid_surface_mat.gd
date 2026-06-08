class_name FluidSurfaceMAT
extends GNMatBase
## Physically-inspired fluid surface material with Fresnel, refraction,
## animated caustics, and wave normal perturbation.
##
## Designed for the FluidVOL → MarchingCubes → GeometryCOMP pipeline,
## but works on any mesh. Accepts an optional normal map TOP input.

var _shader: Shader = null
var _material: ShaderMaterial = null


func _init() -> void:
	node_type = "fluid_surface"


func _init_ports() -> void:
	add_input("normal_map", GNFamily.Type.TOP, false, "Normal map texture (optional)", "Normal Map")
	add_output("out", GNFamily.Type.MAT, "Fluid surface material", "Out")


func _init_parameters() -> void:
	# Color
	add_parameter(GNParameter.create_color("deep_color",
		Color(0.02, 0.08, 0.25, 1.0), "Deep Color", "Color when looking straight down"))
	add_parameter(GNParameter.create_color("shallow_color",
		Color(0.1, 0.5, 0.7, 1.0), "Shallow Color", "Color at glancing angles"))
	add_parameter(GNParameter.create_float("opacity", 0.85, 0.0, 1.0, 0.01,
		"Opacity", "Base surface opacity"))

	# Fresnel
	add_parameter(GNParameter.create_float("fresnel_power", 3.0, 0.5, 10.0, 0.1,
		"Fresnel Power", "Edge reflection falloff exponent"))
	add_parameter(GNParameter.create_float("fresnel_bias", 0.1, 0.0, 1.0, 0.01,
		"Fresnel Bias", "Minimum reflection at normal incidence"))

	# Refraction
	add_parameter(GNParameter.create_float("refraction_strength", 0.15, 0.0, 1.0, 0.01,
		"Refraction", "Screen-space refraction amount"))

	# Surface
	add_parameter(GNParameter.create_float("metallic", 0.0, 0.0, 1.0, 0.01,
		"Metallic", "Metallic material property"))
	add_parameter(GNParameter.create_float("roughness", 0.05, 0.0, 1.0, 0.01,
		"Roughness", "Surface roughness (low = mirror-like)"))
	add_parameter(GNParameter.create_float("specular", 0.8, 0.0, 1.0, 0.01,
		"Specular", "Specular reflection intensity"))

	# Caustics
	add_parameter(GNParameter.create_bool("caustics_enabled", true,
		"Caustics", "Enable animated caustic light pattern"))
	add_parameter(GNParameter.create_float("caustics_scale", 5.0, 0.5, 20.0, 0.1,
		"Caustics Scale", "Size of caustic cells"))
	add_parameter(GNParameter.create_float("caustics_speed", 0.8, 0.0, 5.0, 0.1,
		"Caustics Speed", "Animation speed"))
	add_parameter(GNParameter.create_float("caustics_intensity", 0.4, 0.0, 2.0, 0.01,
		"Caustics Intensity", "Brightness of caustic highlights"))

	# Waves
	add_parameter(GNParameter.create_float("wave_scale", 8.0, 0.5, 50.0, 0.1,
		"Wave Scale", "Frequency of surface wave ripples"))
	add_parameter(GNParameter.create_float("wave_speed", 0.5, 0.0, 5.0, 0.1,
		"Wave Speed", "Wave animation speed"))
	add_parameter(GNParameter.create_float("wave_strength", 0.08, 0.0, 0.5, 0.01,
		"Wave Strength", "Normal perturbation intensity"))

	# Normal map
	add_parameter(GNParameter.create_float("normal_map_strength", 1.0, 0.0, 2.0, 0.01,
		"Normal Map Strength", "Blend strength of the optional normal map input"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null

	# Lazy-init shader material
	if _material == null:
		_shader = load("res://addons/gonodes/shaders/mat/fluid_surface.gdshader") as Shader
		_material = ShaderMaterial.new()
		_material.shader = _shader

	# Set uniforms
	_material.set_shader_parameter("deep_color", get_param_value("deep_color"))
	_material.set_shader_parameter("shallow_color", get_param_value("shallow_color"))
	_material.set_shader_parameter("opacity", get_param_value("opacity"))
	_material.set_shader_parameter("fresnel_power", get_param_value("fresnel_power"))
	_material.set_shader_parameter("fresnel_bias", get_param_value("fresnel_bias"))
	_material.set_shader_parameter("refraction_strength", get_param_value("refraction_strength"))
	_material.set_shader_parameter("metallic_val", get_param_value("metallic"))
	_material.set_shader_parameter("roughness_val", get_param_value("roughness"))
	_material.set_shader_parameter("specular_val", get_param_value("specular"))
	_material.set_shader_parameter("caustics_enabled", get_param_value("caustics_enabled"))
	_material.set_shader_parameter("caustics_scale", get_param_value("caustics_scale"))
	_material.set_shader_parameter("caustics_speed", get_param_value("caustics_speed"))
	_material.set_shader_parameter("caustics_intensity", get_param_value("caustics_intensity"))
	_material.set_shader_parameter("wave_scale", get_param_value("wave_scale"))
	_material.set_shader_parameter("wave_speed", get_param_value("wave_speed"))
	_material.set_shader_parameter("wave_strength", get_param_value("wave_strength"))
	_material.set_shader_parameter("normal_map_strength", get_param_value("normal_map_strength"))

	# Normal map texture
	if tex_in != null and tex_in.texture != null:
		_material.set_shader_parameter("normal_map", tex_in.texture)
		_material.set_shader_parameter("use_normal_map", true)
	else:
		_material.set_shader_parameter("use_normal_map", false)

	var out := _prepare_output()
	out.material = _material
	out.material_label = "FluidSurface\nFresnel %.1f | Rough %.2f" % [
		get_param_value("fresnel_power"), get_param_value("roughness")]
	out.valid = true
	out.timestamp = current_frame
	return out
