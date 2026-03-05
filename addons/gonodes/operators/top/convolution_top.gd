class_name ConvolutionTOP
extends GNTopBase
## Applies a custom NxN convolution kernel (3x3, 5x5, or 7x7).
## Includes presets for Emboss, Sharpen, Edge, Ridge, and Custom.

const PRESETS := {
	"Custom": [],
	"Emboss": [-2, -1, 0, -1, 1, 1, 0, 1, 2],
	"Sharpen": [0, -1, 0, -1, 5, -1, 0, -1, 0],
	"Edge Detect": [-1, -1, -1, -1, 8, -1, -1, -1, -1],
	"Ridge": [0, -1, 0, -1, 4, -1, 0, -1, 0],
	"Gaussian Blur 3x3": [1, 2, 1, 2, 4, 2, 1, 2, 1],
	"Box Blur 3x3": [1, 1, 1, 1, 1, 1, 1, 1, 1],
}


func _init() -> void:
	node_type = "convolution"
	node_description = "Custom NxN kernel convolution with presets (Emboss, Sharpen, Edge, Ridge)."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Convolved texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("preset",
		PackedStringArray(PRESETS.keys()), 1, "Preset", "Convolution kernel preset"))
	add_parameter(GNParameter.create_int("kernel_size", 3, 3, 7, "Kernel Size",
		"Kernel dimension (3, 5, or 7 — must be odd)"))
	add_parameter(GNParameter.create_float("divisor", 1.0, 0.001, 100.0, 0.01, "Divisor",
		"Divide result by this value (use sum of weights for blur kernels)"))
	add_parameter(GNParameter.create_float("bias", 0.0, -1.0, 1.0, 0.01, "Bias",
		"Added to each pixel after division"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("ConvolutionTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/convolution.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res

	var preset_idx: int = get_param_value("preset")
	var preset_name: String = PRESETS.keys()[preset_idx]
	var k_size: int = get_param_value("kernel_size")
	# Force odd
	if k_size % 2 == 0:
		k_size += 1
	k_size = clampi(k_size, 3, 7)

	var kernel_values: Array = PRESETS.get(preset_name, [])
	# Pad to k_size*k_size if preset is a 3x3 but user wants 5x5/7x7
	var total: int = k_size * k_size
	var kernel_floats: PackedFloat32Array = PackedFloat32Array()
	kernel_floats.resize(49)  # max 7x7
	kernel_floats.fill(0.0)

	if kernel_values.size() > 0:
		# If preset is 3x3 but target size is larger, embed in center
		var preset_dim: int = int(sqrt(float(kernel_values.size())))
		var offset: int = (k_size - preset_dim) / 2
		for py in range(preset_dim):
			for px in range(preset_dim):
				var src_idx: int = py * preset_dim + px
				var dst_idx: int = (py + offset) * k_size + (px + offset)
				if dst_idx < 49:
					kernel_floats[dst_idx] = float(kernel_values[src_idx])
	else:
		# Custom — identity
		var center: int = total / 2
		if center < 49:
			kernel_floats[center] = 1.0

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("kernel", kernel_floats)
	_material.set_shader_parameter("kernel_size", k_size)
	_material.set_shader_parameter("divisor", get_param_value("divisor"))
	_material.set_shader_parameter("bias", get_param_value("bias"))

	_cached_tex_data.resolution = res
	return _cached_tex_data
