class_name CompositeTOP
extends GNTopBase
## Blends two input textures (A and B) using a configurable blend operation.
## Uses a SubViewport with a composite shader.
## SubViewport is a child of this Node — freed automatically on removal.

enum BlendOp { ADD, MULTIPLY, OVER, SCREEN, SUBTRACT, DIFFERENCE }

var _shader: Shader = null


func _init() -> void:
	node_type = "composite"
	node_description = "Blend two textures (Add, Multiply, Over, Screen, etc.)."


func _init_ports() -> void:
	add_input("A", GNFamily.Type.TOP, false, "First texture (base)")
	add_input("B", GNFamily.Type.TOP, false, "Second texture (blend)")
	add_output("out", GNFamily.Type.TOP, "Composited texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("operation",
		PackedStringArray(["Add", "Multiply", "Over", "Screen", "Subtract", "Difference"]), 0, "", "Blend mode"))
	add_parameter(GNParameter.create_float("opacity", 1.0, 0.0, 1.0, 0.01, "", "Blend opacity"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_a: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	var tex_b: GNTextureData = inputs[1] as GNTextureData if inputs.size() > 1 and inputs[1] is GNTextureData else null

	if tex_a == null:
		GNLogger.warn("CompositeTOP", "'%s' — no valid input on port A" % id)
		return null

	var res: Vector2i = tex_a.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/composite.gdshader", true, false, res)

	var op_idx: int = get_param_value("operation")
	var opacity_val: float = get_param_value("opacity")

	# Match viewport to input A's resolution
	if _viewport.size != res:
		_viewport.size = res

	# Set shader uniforms — input textures are GPU references (zero-copy)
	_material.set_shader_parameter("texture_a", tex_a.texture)
	if tex_b != null:
		_material.set_shader_parameter("texture_b", tex_b.texture)
	_material.set_shader_parameter("operation", op_idx)
	_material.set_shader_parameter("opacity", opacity_val)

	_cached_tex_data.resolution = res

	return _cached_tex_data

