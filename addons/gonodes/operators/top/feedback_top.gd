class_name FeedbackTOP
extends GNTopBase
## Creates a temporal feedback loop: blends the current input with the previous
## frame's output, transforming the feedback UVs for motion effects.
## The internal feedback buffer is one frame behind.

var _shader: Shader = null
var _blit: Dictionary = {}
var _frame_count: int = 0


func _init() -> void:
	node_type = "feedback"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Feedback-blended texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("mix", 0.9, 0.0, 1.0, 0.01, "Feedback Mix", "Persistence (higher = longer trails)"))
	add_parameter(GNParameter.create_vector2("translate", Vector2.ZERO, "Translate", "Feedback UV translation per frame"))
	add_parameter(GNParameter.create_float("rotate", 0.0, null, null, 0.01, "Rotate (rad)", "Feedback rotation per frame"))
	add_parameter(GNParameter.create_vector2("scale", Vector2(1.0, 1.0), "Scale", "Feedback scale per frame"))
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
		_destroy_blit()

	if do_reset:
		_destroy_blit()
		_frame_count = 0

	_ensure_blit(res)

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _frame_count > 0:
		_material.set_shader_parameter("feedback_tex", (_blit.viewport as SubViewport).get_texture())
	else:
		_material.set_shader_parameter("feedback_tex", tex_in.texture)

	_material.set_shader_parameter("feedback_mix", mix_val)
	_material.set_shader_parameter("fb_translate", trans)
	_material.set_shader_parameter("fb_rotate", rot)
	_material.set_shader_parameter("fb_scale", scl)

	# Point blit viewport at main viewport output for GPU-side capture
	(_blit.canvas as TextureRect).texture = _viewport.get_texture()
	_frame_count += 1

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_blit(res: Vector2i) -> void:
	if not _blit.is_empty() and (_blit.viewport as SubViewport).size == res:
		return
	_destroy_blit()
	_blit = GNTopBase._create_blit_viewport(self, "FeedbackBlit", res, true)


func _destroy_blit() -> void:
	if _blit.has("viewport") and is_instance_valid(_blit.viewport):
		(_blit.viewport as SubViewport).queue_free()
	_blit = {}

