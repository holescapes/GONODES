class_name CompositeTOP
extends GNNode
## Blends two input textures (A and B) using a configurable blend operation.
## Uses a SubViewport with a composite shader.
## SubViewport is a child of this Node — freed automatically on removal.

enum BlendOp { ADD, MULTIPLY, OVER, SCREEN, SUBTRACT, DIFFERENCE }

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "composite"
	family = GNFamily.Type.TOP
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

	_ensure_viewport()

	var op_idx: int = get_param_value("operation")
	var opacity_val: float = get_param_value("opacity")

	# Match viewport to input A's resolution
	var res: Vector2i = tex_a.resolution
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


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/composite.gdshader") as Shader

	# Create SubViewport as child
	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	_material = ShaderMaterial.new()
	_material.shader = _shader

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("CompositeTOP", "'%s' viewport created: %s" % [id, str(_viewport.size)])
