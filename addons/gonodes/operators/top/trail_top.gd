class_name TrailTOP
extends GNTopBase
## Motion trail / frame persistence effect.
## Blends the current input with the accumulated previous output at a
## configurable decay rate, creating ghost / echo / trail effects.

var _feedback_texture: ImageTexture = null
var _frame_count: int = 0


func _init() -> void:
	node_type = "trail"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Trail output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("decay", 0.9, 0.0, 1.0, 0.01,
		"Decay", "Trail persistence (higher = longer trails)"))
	add_parameter(GNParameter.create_float("brightness", 1.0, 0.0, 5.0, 0.01,
		"Brightness", "Brightness multiplier on accumulated trail"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Clear the trail buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("TrailTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/trail.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		_feedback_texture = null

	if get_param_value("reset"):
		_feedback_texture = null
		_frame_count = 0

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _feedback_texture != null:
		_material.set_shader_parameter("prev_tex", _feedback_texture)
	else:
		_material.set_shader_parameter("prev_tex", tex_in.texture)

	_material.set_shader_parameter("decay", get_param_value("decay"))
	_material.set_shader_parameter("brightness", get_param_value("brightness"))

	_frame_count += 1
	if _frame_count > 1:
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
