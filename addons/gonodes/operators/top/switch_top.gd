class_name SwitchTOP
extends GNTopBase
## Selects one of multiple TOP inputs based on the index parameter.
## Like TouchDesigner's Switch TOP.  Uses dynamic auto-grow input ports —
## connect to add more slots, disconnect to shrink.
## When "Blend Between" is enabled, crossfades between adjacent inputs
## using the fractional part of the blend position.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.TOP, "in", "Texture Input")
	add_output("out", GNFamily.Type.TOP, "Selected texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Input Index",
		"Which input to output (0-based)"))
	add_parameter(GNParameter.create_bool("blend", false, "Blend Between",
		"Crossfade between adjacent inputs using Blend Position"))
	add_parameter(GNParameter.create_float("blend_pos", 0.0, 0.0, 1.0, 0.01, "Blend Position",
		"Fractional position through the input list (0.0 = first, 1.0 = last)"))


## Auto-adjust index param max_value when ports grow/shrink.
func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	var idx_param := get_parameter("index")
	if idx_param:
		var max_idx: int = maxi(input_ports.size() - 2, 0)  # exclude trailing empty
		idx_param.max_value = max_idx
		if int(idx_param.value) > max_idx:
			idx_param.set_value(max_idx)

func get_active_input_indices() -> PackedInt32Array:
	var do_blend: bool = get_param_value("blend")
	if not do_blend:
		# get_param_value returns resolved_value for expression-mode params,
		# which holds the last frame's evaluated result.  The cook engine
		# marks _active_set_dirty whenever an expression value changes, so
		# the active chain converges within one frame.
		var idx: int = clampi(get_param_value("index"), 0, maxi(input_ports.size() - 1, 0))
		return PackedInt32Array([idx])
	# Blend mode uses all inputs
	return PackedInt32Array()


func _cook(inputs: Array[GNData]) -> GNData:
	var do_blend: bool = get_param_value("blend")

	if not do_blend:
		# ── Discrete switch ──
		var idx: int = get_param_value("index")
		idx = clampi(idx, 0, inputs.size() - 1)
		if idx < inputs.size() and inputs[idx] is GNTextureData:
			return inputs[idx]
		# Requested input not available yet (chain activating after index
		# change).  Hold the previous frame's output so the viewer sees a
		# seamless freeze-frame instead of a black flash.
		return cached_output

	# ── Blend between adjacent inputs ──
	# Collect valid texture inputs
	var valid_textures: Array[GNTextureData] = []
	for inp in inputs:
		if inp is GNTextureData:
			valid_textures.append(inp as GNTextureData)
	if valid_textures.is_empty():
		return null
	if valid_textures.size() == 1:
		return valid_textures[0]

	# Map blend_pos [0,1] to the input list
	var blend_pos: float = get_param_value("blend_pos")
	var span: float = float(valid_textures.size() - 1)
	var f_idx: float = clampf(blend_pos * span, 0.0, span)
	var lo: int = int(floor(f_idx))
	var hi: int = mini(lo + 1, valid_textures.size() - 1)
	var frac: float = f_idx - float(lo)

	var tex_lo: GNTextureData = valid_textures[lo]
	var tex_hi: GNTextureData = valid_textures[hi]

	# Pure endpoints — skip shader
	if lo == hi or frac < 0.001:
		return tex_lo
	if frac > 0.999:
		return tex_hi

	# Crossfade via shader
	var res: Vector2i = tex_lo.resolution
	_init_shader_viewport("res://addons/gonodes/shaders/top/switch_blend.gdshader", true, true, res)
	if _viewport.size != res:
		_viewport.size = res

	_material.set_shader_parameter("texture_a", tex_lo.texture)
	_material.set_shader_parameter("texture_b", tex_hi.texture)
	_material.set_shader_parameter("blend_amount", frac)

	_cached_tex_data.resolution = res
	return _cached_tex_data
