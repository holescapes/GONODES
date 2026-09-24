class_name FrameDifferenceTOP
extends GNTopBase
## Subtracts the previous frame from the current frame to produce a motion
## delta image.  Core building block for motion detection, VJ reactivity,
## and edge-of-motion effects.  Uses feedback ping-pong internally.

var _blit: Dictionary = {}
var _frame_count: int = 0


func _init() -> void:
	node_type = "frame_difference"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Difference texture", "Out")


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
		_ensure_viewport_size(res)
		_destroy_blit()

	var do_reset: bool = get_param_value("reset")
	if do_reset:
		_destroy_blit()
		_frame_count = 0

	_ensure_blit(res)

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _frame_count > 0:
		_material.set_shader_parameter("prev_tex", (_blit.viewport as SubViewport).get_texture())
	else:
		_material.set_shader_parameter("prev_tex", tex_in.texture)

	_material.set_shader_parameter("mode", get_param_value("mode"))
	_material.set_shader_parameter("gain", get_param_value("gain"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	# Point blit viewport at current input for next frame's prev_tex
	(_blit.canvas as TextureRect).texture = tex_in.texture
	_frame_count += 1

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_blit(res: Vector2i) -> void:
	if not _blit.is_empty() and (_blit.viewport as SubViewport).size == res:
		return
	_destroy_blit()
	_blit = GNTopBase._create_blit_viewport(self, "PrevFrameBlit", res, true)


func _destroy_blit() -> void:
	if _blit.has("viewport") and is_instance_valid(_blit.viewport):
		(_blit.viewport as SubViewport).queue_free()
	_blit = {}
