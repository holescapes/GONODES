class_name GlitchTOP
extends GNTopBase
## Digital glitch effect — block displacement, channel shift, scan-line jitter,
## horizontal tears, colour crush, static noise, and V002-style stale-frame
## injection.

var _stale_texture: ImageTexture = null
var _frame_count: int = 0


func _init() -> void:
	node_type = "glitch"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture")
	add_output("out", GNFamily.Type.TOP, "Glitched texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("intensity", 0.3, 0.0, 1.0, 0.01,
		"Intensity", "Probability and strength of glitch blocks"))
	add_parameter(GNParameter.create_float("block_size", 32.0, 4.0, 128.0, 1.0,
		"Block Size", "Glitch block size in pixels"))
	add_parameter(GNParameter.create_float("channel_shift", 0.01, 0.0, 0.05, 0.001,
		"Channel Shift", "RGB channel separation amount"))
	add_parameter(GNParameter.create_float("speed", 8.0, 0.1, 30.0, 0.1,
		"Speed", "Glitch animation speed"))
	add_parameter(GNParameter.create_float("scan_jitter", 0.0, 0.0, 0.1, 0.001,
		"Scan Jitter", "VHS-style per-scanline horizontal displacement"))
	add_parameter(GNParameter.create_float("tear_strength", 0.0, 0.0, 1.0, 0.01,
		"Tear Strength", "Horizontal tear band displacement"))
	add_parameter(GNParameter.create_float("color_crush", 0.0, 0.0, 1.0, 0.01,
		"Color Crush", "Bit-depth reduction in glitch blocks (0 = off, 1 = extreme)"))
	add_parameter(GNParameter.create_float("noise_amount", 0.0, 0.0, 1.0, 0.01,
		"Noise", "Analog static / digital snow injection"))
	add_parameter(GNParameter.create_float("stale_mix", 0.0, 0.0, 1.0, 0.01,
		"Stale Frame", "V002-style: inject data from old frames into glitch blocks"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GlitchTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/glitch.gdshader", true, true, res)

	if _viewport.size != res:
		_viewport.size = res
		_stale_texture = null

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("block_size", get_param_value("block_size"))
	_material.set_shader_parameter("channel_shift", get_param_value("channel_shift"))
	_material.set_shader_parameter("speed", get_param_value("speed"))
	_material.set_shader_parameter("time_val", elapsed_time)
	_material.set_shader_parameter("scan_jitter", get_param_value("scan_jitter"))
	_material.set_shader_parameter("tear_strength", get_param_value("tear_strength"))
	_material.set_shader_parameter("color_crush", get_param_value("color_crush"))
	_material.set_shader_parameter("noise_amount", get_param_value("noise_amount"))

	var stale_val: float = get_param_value("stale_mix")
	_material.set_shader_parameter("stale_mix", stale_val)

	if stale_val > 0.0:
		if _stale_texture != null:
			_material.set_shader_parameter("stale_tex", _stale_texture)
		else:
			_material.set_shader_parameter("stale_tex", tex_in.texture)
		_frame_count += 1
		if _frame_count > 1:
			_maybe_capture_stale.call_deferred(stale_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Capture the viewport output for the stale buffer.  Higher stale_mix values
## reduce the update frequency so the buffer becomes genuinely stale — blocks
## may show data from many frames ago, mimicking V002's uninitialised FBO reads.
func _maybe_capture_stale(stale_val: float) -> void:
	if _viewport == null:
		return
	# Update probability decreases with staleness: at 1.0 → ~10%, at 0.1 → ~90%
	var update_prob: float = clamp(1.0 - stale_val * 0.9, 0.1, 1.0)
	if _stale_texture != null and randf() > update_prob:
		return  # Skip this frame — keep the buffer stale
	var img: Image = _viewport.get_texture().get_image()
	if img == null:
		return
	if _stale_texture == null:
		_stale_texture = ImageTexture.create_from_image(img)
	else:
		_stale_texture.update(img)
