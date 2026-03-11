class_name TransformTOP
extends GNTopBase
## Applies 2D spatial transformations (translate, rotate, scale) to an input texture.

var _shader: Shader = null


func _init() -> void:
	node_type = "transform"
	node_description = "2D translate, rotate, and scale with extend modes."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Transformed texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO, "", "UV translation"))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)", "Rotation in radians"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "", "UV scale"))
	add_parameter(GNParameter.create_vector2("pivot", Vector2(0.5, 0.5), "", "Transform pivot point in UV space"))
	add_parameter(GNParameter.create_enum("extend",
		PackedStringArray(["Clamp", "Repeat", "Mirror", "Zero"]), 0, "", "Edge extension mode"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("TransformTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/transform2d.gdshader", true, true, res)

	var trans: Vector2 = get_param_value("translate")
	var rot: float = get_param_value("rotate")
	var scl: Vector2 = get_param_value("scale")
	var pvt: Vector2 = get_param_value("pivot")
	var ext: int = get_param_value("extend")

	if _viewport.size != res:
		_viewport.size = res

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("translate", trans)
	_material.set_shader_parameter("rotate_angle", rot)
	_material.set_shader_parameter("scale_amount", scl)
	_material.set_shader_parameter("pivot", pvt)
	_material.set_shader_parameter("extend_mode", ext)

	_cached_tex_data.resolution = res

	# Apply inverse spatial transform to panel_sources so interactive hits
	# map back through translate/rotate/scale to the original panel viewport.
	#
	# The shader maps output UV → source UV as follows (see transform2d.gdshader):
	#   1. uv -= pivot
	#   2. uv /= scale
	#   3. uv = rotate(uv, rotate_angle)   [forward rotate in shader = inverse of visual]
	#   4. uv -= translate
	#   5. uv += pivot
	#
	# We replicate the same sequence as a pixel-space Transform2D so that
	# hit_test(output_point) yields the correct source-space coordinate.
	if tex_in.panel_sources.size() > 0:
		_cached_tex_data.panel_sources.clear()
		var fres := Vector2(res)
		var pix_pivot := pvt * fres
		var pix_trans := trans * fres

		# Build the output→source mapping matching the shader steps:
		var inv_t := Transform2D.IDENTITY
		# Step 1: subtract pivot
		inv_t = Transform2D(0.0, -pix_pivot) * inv_t
		# Step 2: divide by scale (inverse scale)
		var inv_scl := Vector2(1.0 / scl.x, 1.0 / scl.y) if scl.x != 0.0 and scl.y != 0.0 else Vector2.ONE
		inv_t = Transform2D(Vector2(inv_scl.x, 0), Vector2(0, inv_scl.y), Vector2.ZERO) * inv_t
		# Step 3: rotate by rotate_angle (shader applies forward rotation)
		inv_t = Transform2D(rot, Vector2.ZERO) * inv_t
		# Step 4: subtract translate
		inv_t = Transform2D(0.0, -pix_trans) * inv_t
		# Step 5: add pivot back
		inv_t = Transform2D(0.0, pix_pivot) * inv_t

		for ps in tex_in.panel_sources:
			var copy: GNPanelSource = ps.duplicate_source()
			copy.transform = copy.transform * inv_t
			_cached_tex_data.panel_sources.append(copy)

	return _cached_tex_data

