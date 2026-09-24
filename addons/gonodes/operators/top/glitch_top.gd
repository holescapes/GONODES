class_name GlitchTOP
extends GNTopBase
## Digital glitch effect — block displacement, channel shift, scan-line jitter,
## horizontal tears, colour crush, static noise, and V002-style stale-frame
## injection.

var _blit: Dictionary = {}
var _frame_count: int = 0
var _update_stale: bool = false


func _init() -> void:
	node_type = "glitch"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Glitched texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_enum("mode",
		PackedStringArray(["Blocks", "VHS", "Data Moshing", "Snow"]), 0,
		"Mode", "Glitch style — chain multiple GlitchTOPs for combined effects"))
	add_parameter(GNParameter.create_float("intensity", 0.3, 0.0, 1.0, 0.01,
		"Intensity", "Probability and strength of glitch blocks"))
	var p_bs := GNParameter.create_float("block_size", 32.0, 4.0, 128.0, 1.0,
		"Block Size", "Glitch block size in pixels")
	p_bs.visibility_rule = {"param": "mode", "values": [0, 1, 2]}
	add_parameter(p_bs)
	var p_cs := GNParameter.create_float("channel_shift", 0.01, 0.0, 0.05, 0.001,
		"Channel Shift", "RGB channel separation amount")
	p_cs.visibility_rule = {"param": "mode", "values": [0, 1]}
	add_parameter(p_cs)
	add_parameter(GNParameter.create_float("speed", 8.0, 0.1, 30.0, 0.1,
		"Speed", "Glitch animation speed"))
	var p_sj := GNParameter.create_float("scan_jitter", 0.0, 0.0, 0.1, 0.001,
		"Scan Jitter", "VHS-style per-scanline horizontal displacement")
	p_sj.visibility_rule = {"param": "mode", "values": [1]}
	add_parameter(p_sj)
	var p_ts := GNParameter.create_float("tear_strength", 0.0, 0.0, 1.0, 0.01,
		"Tear Strength", "Horizontal tear band displacement")
	p_ts.visibility_rule = {"param": "mode", "values": [1]}
	add_parameter(p_ts)
	var p_cc := GNParameter.create_float("color_crush", 0.0, 0.0, 1.0, 0.01,
		"Color Crush", "Bit-depth reduction in glitch blocks (0 = off, 1 = extreme)")
	p_cc.visibility_rule = {"param": "mode", "values": [0]}
	add_parameter(p_cc)
	var p_na := GNParameter.create_float("noise_amount", 0.0, 0.0, 1.0, 0.01,
		"Noise", "Analog static / digital snow injection")
	p_na.visibility_rule = {"param": "mode", "values": [1, 3]}
	add_parameter(p_na)
	var p_sm := GNParameter.create_float("stale_mix", 0.0, 0.0, 1.0, 0.01,
		"Stale Frame", "V002-style: inject data from old frames into glitch blocks")
	p_sm.visibility_rule = {"param": "mode", "values": [2]}
	add_parameter(p_sm)


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("GlitchTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/glitch.gdshader", true, true, res)

	if _viewport.size != res:
		_ensure_viewport_size(res)
		_destroy_blit()
		_frame_count = 0

	(_canvas as TextureRect).texture = tex_in.texture
	_material.set_shader_parameter("source_tex", tex_in.texture)
	_material.set_shader_parameter("intensity", get_param_value("intensity"))
	_material.set_shader_parameter("speed", get_param_value("speed"))
	_material.set_shader_parameter("time_val", elapsed_time)
	_material.set_shader_parameter("mode", get_param_value("mode"))

	# Gate layers by mode:
	# 0=Blocks, 1=VHS, 2=Data Moshing, 3=Snow
	var mode: int = get_param_value("mode")
	var block_size: float = get_param_value("block_size")
	var channel_shift: float = get_param_value("channel_shift")
	var scan_jitter: float = get_param_value("scan_jitter")
	var tear_strength: float = get_param_value("tear_strength")
	var color_crush: float = get_param_value("color_crush")
	var noise_amount: float = get_param_value("noise_amount")
	var stale_val: float = get_param_value("stale_mix")

	match mode:
		0:  # Blocks — displacement + channel shift + color crush
			scan_jitter = 0.0
			tear_strength = 0.0
			noise_amount = 0.0
			stale_val = 0.0
		1:  # VHS — scan jitter + tears + noise
			color_crush = 0.0
			stale_val = 0.0
		2:  # Data Moshing — stale frames + block displacement
			scan_jitter = 0.0
			tear_strength = 0.0
			noise_amount = 0.0
			color_crush = 0.0
			channel_shift = 0.0
			stale_val = maxf(stale_val, 0.3)
		3:  # Snow — noise only
			channel_shift = 0.0
			scan_jitter = 0.0
			tear_strength = 0.0
			color_crush = 0.0
			stale_val = 0.0
			noise_amount = maxf(noise_amount, 0.1)

	_material.set_shader_parameter("block_size", block_size)
	_material.set_shader_parameter("channel_shift", channel_shift)
	_material.set_shader_parameter("scan_jitter", scan_jitter)
	_material.set_shader_parameter("tear_strength", tear_strength)
	_material.set_shader_parameter("color_crush", color_crush)
	_material.set_shader_parameter("noise_amount", noise_amount)

	_material.set_shader_parameter("stale_mix", stale_val)
	_update_stale = false

	if stale_val > 0.0:
		_ensure_blit(res)
		if _frame_count > 0:
			_material.set_shader_parameter("stale_tex", (_blit.viewport as SubViewport).get_texture())
		else:
			_material.set_shader_parameter("stale_tex", tex_in.texture)

		var update_prob: float = clamp(1.0 - stale_val * 0.9, 0.1, 1.0)
		if _frame_count < 2 or randf() <= update_prob:
			(_blit.canvas as TextureRect).texture = _viewport.get_texture()
			_update_stale = true
		_frame_count += 1

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Only render the stale blit viewport on frames where we want to update it.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	if result != null and not _blit.is_empty() and not _update_stale:
		(_blit.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	return result


func _ensure_blit(res: Vector2i) -> void:
	if not _blit.is_empty() and (_blit.viewport as SubViewport).size == res:
		return
	_destroy_blit()
	_blit = GNTopBase._create_blit_viewport(self, "StaleBlit", res, true)


func _destroy_blit() -> void:
	if _blit.has("viewport") and is_instance_valid(_blit.viewport):
		(_blit.viewport as SubViewport).queue_free()
	_blit = {}
	_frame_count = 0
