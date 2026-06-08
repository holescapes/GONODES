class_name TemporalDenoiseTOP
extends GNTopBase
## Multi-frame temporal denoising via adaptive frame accumulation.
##
## Blends the current frame with the accumulated previous output, using
## per-pixel motion-aware rejection to prevent ghosting on moving content.
## Effective for smoothing noisy sources (cameras, generative noise) while
## preserving sharp edges on motion.
##
## Parameters:
##   strength — how much of the previous frame to blend in (0 = off, 1 = max)
##   threshold — difference above which a pixel is treated as motion and
##               the current frame is preferred (avoids ghosting)
##   reset — clears the accumulation buffer

var _blit: Dictionary = {}
var _frame_count: int = 0


func _init() -> void:
	node_type = "temporaldenoise"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture to denoise", "In")
	add_output("out", GNFamily.Type.TOP, "Denoised output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("strength", 0.8, 0.0, 1.0, 0.01,
		"Strength", "Temporal blend strength (higher = smoother, more latent)"))
	add_parameter(GNParameter.create_float("threshold", 0.1, 0.0, 1.0, 0.01,
		"Threshold", "Motion rejection threshold (higher = more tolerant of differences)"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Clear the accumulation buffer"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/temporal_denoise.gdshader", true, false, res)

	if _viewport.size != res:
		_viewport.size = res
		_destroy_blit()

	if get_param_value("reset"):
		_destroy_blit()
		_frame_count = 0

	_ensure_blit(res)

	_material.set_shader_parameter("source_tex", tex_in.texture)

	if _frame_count > 0:
		_material.set_shader_parameter("prev_tex", (_blit.viewport as SubViewport).get_texture())
	else:
		_material.set_shader_parameter("prev_tex", tex_in.texture)

	_material.set_shader_parameter("strength", get_param_value("strength"))
	_material.set_shader_parameter("threshold", get_param_value("threshold"))

	(_blit.canvas as TextureRect).texture = _viewport.get_texture()
	_frame_count += 1

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _ensure_blit(res: Vector2i) -> void:
	if not _blit.is_empty() and (_blit.viewport as SubViewport).size == res:
		return
	_destroy_blit()
	_blit = GNTopBase._create_blit_viewport(self, "DenoiseBlit", res, true)


func _destroy_blit() -> void:
	if _blit.has("viewport") and is_instance_valid(_blit.viewport):
		(_blit.viewport as SubViewport).queue_free()
	_blit = {}
