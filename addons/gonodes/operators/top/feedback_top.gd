class_name FeedbackTOP
extends GNNode
## Creates a temporal feedback loop: blends the current input with the previous
## frame's output, transforming the feedback UVs for motion effects.
## The internal feedback buffer is one frame behind.

var _shader: Shader = null
var _viewport: SubViewport = null
var _canvas: ColorRect = null
var _material: ShaderMaterial = null
var _cached_tex_data: GNTextureData = null
var _feedback_texture: ImageTexture = null
var _frame_count: int = 0


func _init() -> void:
	node_type = "feedback"
	family = GNFamily.Type.TOP


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP)
	add_output("out", GNFamily.Type.TOP)


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("mix", 0.9, 0.0, 1.0, 0.01, "Feedback Mix"))
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0)))
	add_parameter(GNParameter.create_bool("reset", false, "Reset Feedback"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("FeedbackTOP", "'%s' — no valid input" % id)
		return null

	_ensure_viewport()

	var mix_val: float = get_param_value("mix")
	var trans: Vector2 = get_param_value("translate")
	var rot: float = get_param_value("rotate")
	var scl: Vector2 = get_param_value("scale")
	var do_reset: bool = get_param_value("reset")
	var res: Vector2i = tex_in.resolution

	if _viewport.size != res:
		_viewport.size = res
		_canvas.size = Vector2(res)
		_feedback_texture = null  # Force re-create on resize

	# Reset feedback buffer on request
	if do_reset:
		_feedback_texture = null
		_frame_count = 0

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _feedback_texture != null:
		_material.set_shader_parameter("feedback_tex", _feedback_texture)
	else:
		# First frame — use source as feedback too
		_material.set_shader_parameter("feedback_tex", tex_in.texture)

	_material.set_shader_parameter("feedback_mix", mix_val)
	_material.set_shader_parameter("fb_translate", trans)
	_material.set_shader_parameter("fb_rotate", rot)
	_material.set_shader_parameter("fb_scale", scl)

	# Capture current viewport output for next frame's feedback
	_frame_count += 1
	if _frame_count > 1:
		# We have to defer capturing because viewport renders later
		_capture_feedback.call_deferred()

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _capture_feedback() -> void:
	if _viewport == null:
		return
	var img: Image = _viewport.get_texture().get_image()
	if img == null:
		return
	if _feedback_texture == null:
		_feedback_texture = ImageTexture.create_from_image(img)
	else:
		_feedback_texture.update(img)


func _ensure_viewport() -> void:
	if _viewport != null:
		return

	_shader = load("res://addons/gonodes/shaders/feedback.gdshader") as Shader

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
	_canvas.size = Vector2(512, 512)
	_canvas.material = _material
	_viewport.add_child(_canvas)

	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("FeedbackTOP", "'%s' viewport created" % id)
