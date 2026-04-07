class_name FrameDifferenceTOP
extends GNTopBase
## Subtracts the previous frame from the current frame to produce a motion
## delta image.  Core building block for motion detection, VJ reactivity,
## and edge-of-motion effects.  Uses feedback ping-pong internally.

var _prev_texture: ImageTexture = null
var _frame_count: int = 0


func _init() -> void:
	node_type = "frame_difference"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Difference texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Absolute", "Signed"]), 0,
		"Mode", "Absolute = |curr-prev|, Signed = offset to mid-gray"))
	add_parameter(GNParameter.create_float("gain", 1.0, 0.0, 10.0, 0.1,
		"Gain", "Difference intensity multiplier"))
	add_parameter(GNParameter.create_float("threshold", 0.0, 0.0, 1.0, 0.01,
		"Threshold", "Suppress differences below this luminance (noise gate)"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Clear the previous frame buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("FrameDifferenceTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/frame_difference.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		_prev_texture = null

	var do_reset: bool = get_param_value("reset")
	if do_reset:
		_prev_texture = null
		_frame_count = 0

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _prev_texture != null:
		_material.set_shader_parameter("prev_tex", _prev_texture)
	else:
		_material.set_shader_parameter("prev_tex", tex_in.texture)

	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("gain", get_param_value("gain"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	_frame_count += 1
	if _frame_count > 1:
		_capture_prev.call_deferred()

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _capture_prev() -> void:
	if _viewport == null:
		return
	# Capture the *source input* (not the diff output) for next frame comparison.
	# We read the source_tex that was set on the material.
	var src_tex: Texture2D = _material.get_shader_parameter("source_tex")
	if src_tex == null:
		return
	var img: Image = src_tex.get_image()
	if img == null:
		return
	if _prev_texture == null:
		_prev_texture = ImageTexture.create_from_image(img)
	else:
		_prev_texture.update(img)
