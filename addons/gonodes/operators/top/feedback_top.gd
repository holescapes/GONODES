class_name FeedbackTOP
extends GNTopBase
## Creates a temporal feedback loop: blends the current input with the previous
## frame's output, transforming the feedback UVs for motion effects.
## The internal feedback buffer is one frame behind.

var _shader: Shader = null
var _feedback_texture: ImageTexture = null
var _frame_count: int = 0


func _init() -> void:
	node_type = "feedback"
	node_description = "Blends current frame with previous frame for trails/echoes."


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Feedback-blended texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("mix", 0.9, 0.0, 1.0, 0.01, "Feedback Mix", "Persistence (higher = longer trails)"))
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO, "", "Feedback UV translation per frame"))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)", "Feedback rotation per frame"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "", "Feedback scale per frame"))
	add_parameter(GNParameter.create_bool("reset", false, "Reset Feedback", "Clear the feedback buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = inputs[0] as GNTextureData if inputs.size() > 0 and inputs[0] is GNTextureData else null
	if tex_in == null:
		GNLogger.warn("FeedbackTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/feedback.gdshader", true, false, res)

	var mix_val: float = get_param_value("mix")
	var trans: Vector2 = get_param_value("translate")
	var rot: float = get_param_value("rotate")
	var scl: Vector2 = get_param_value("scale")
	var do_reset: bool = get_param_value("reset")

	if _viewport.size != res:
		_viewport.size = res
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

