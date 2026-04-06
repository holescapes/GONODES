class_name ReactionDiffusionTOP
extends GNTopBase
## Gray-Scott reaction-diffusion simulation rendered as a texture.
##
## Uses SCREEN_TEXTURE feedback to evolve two chemicals (U and V) each frame.
## Different feed_rate (f) and kill_rate (k) values produce wildly different
## patterns: spots, stripes, mitosis, coral, worms, waves, etc.
##
## A second viewport colorizes the raw simulation buffer for display.
##
## TouchDesigner equivalent: GLSL Multi-Pass TOP with RD equations.

var _sim_viewport: SubViewport = null
var _sim_material: ShaderMaterial = null
var _render_viewport: SubViewport = null
var _render_material: ShaderMaterial = null
var _last_res: Vector2i = Vector2i.ZERO
var _needs_reset: bool = true


func _init() -> void:
	node_type = "reaction_diffusion"
	time_dependent = true


func _init_ports() -> void:
	add_input("seed", GNFamily.Type.TOP, true, "Optional seed mask texture")
	add_output("out", GNFamily.Type.TOP, "Rendered pattern texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Simulation / output resolution"))
	add_parameter(GNParameter.create_float("feed_rate", 0.055, 0.0, 0.1, 0.001,
		"Feed Rate (f)", "Replenishment rate of U (controls pattern type)"))
	add_parameter(GNParameter.create_float("kill_rate", 0.062, 0.0, 0.1, 0.001,
		"Kill Rate (k)", "Removal rate of V (controls pattern type)"))
	add_parameter(GNParameter.create_float("diffusion_u", 1.0, 0.0, 2.0, 0.01,
		"Diffusion U", "Diffusion rate of chemical U"))
	add_parameter(GNParameter.create_float("diffusion_v", 0.5, 0.0, 2.0, 0.01,
		"Diffusion V", "Diffusion rate of chemical V"))
	add_parameter(GNParameter.create_float("speed", 1.0, 0.1, 5.0, 0.1,
		"Speed", "Simulation time step multiplier"))
	add_parameter(GNParameter.create_int("steps_per_frame", 4, 1, 32,
		"Steps/Frame", "Sub-steps per render (more = faster evolution)"))
	add_parameter(GNParameter.create_vector2("seed_pos", Vector2(0.5, 0.5),
		"Seed Pos", "Position of circular seed injection (0-1)"))
	add_parameter(GNParameter.create_float("seed_radius", 0.05, 0.01, 0.3, 0.01,
		"Seed Radius", "Radius of seed circle"))
	add_parameter(GNParameter.create_float("seed_amount", 0.25, 0.0, 1.0, 0.01,
		"Seed Amount", "Concentration of V injected by seed"))
	add_parameter(GNParameter.create_bool("add_seed", false,
		"Add Seed", "Inject seed at seed_pos this frame"))
	add_parameter(GNParameter.create_enum("color_mode",
		PackedStringArray(["Mono", "Heat Map", "Custom"]),
		0, "Color Mode", "Output coloring style"))
	add_parameter(GNParameter.create_color("color_a", Color.BLACK,
		"Color A", "Background color (Custom mode)"))
	add_parameter(GNParameter.create_color("color_b", Color.WHITE,
		"Color B", "Pattern color (Custom mode)"))
	add_parameter(GNParameter.create_float("brightness", 1.0, 0.1, 5.0, 0.1,
		"Brightness", "Output brightness multiplier"))
	add_parameter(GNParameter.create_bool("invert", false,
		"Invert", "Invert pattern (swap foreground/background)"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Re-initialize the simulation"))

	# Presets for common patterns
	add_parameter(GNParameter.create_enum("preset",
		PackedStringArray(["Custom", "Mitosis", "Coral", "Maze", "Spots", "Worms", "Waves"]),
		0, "Preset", "Quick parameter presets for common patterns"))


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var do_reset: bool = get_param_value("reset")
	var preset: int = get_param_value("preset")

	# Apply preset if changed from Custom
	if preset > 0:
		_apply_preset(preset)
		set_param_value("preset", 0)

	# Build VPs once on first cook
	if _sim_viewport == null:
		_build_pipeline(res)
		_last_res = res
		_needs_reset = true

	# Resize existing VPs when resolution changes (no rebuild needed)
	if _last_res != res:
		_sim_viewport.size = res
		_render_viewport.size = res
		_last_res = res
		_needs_reset = true

	if do_reset:
		_needs_reset = true
		set_param_value("reset", false)

	# --- Simulation uniforms ---
	_sim_material.set_shader_parameter("resolution", Vector2(res))
	_sim_material.set_shader_parameter("feed_rate", get_param_value("feed_rate"))
	_sim_material.set_shader_parameter("kill_rate", get_param_value("kill_rate"))
	_sim_material.set_shader_parameter("diffusion_u", get_param_value("diffusion_u"))
	_sim_material.set_shader_parameter("diffusion_v", get_param_value("diffusion_v"))
	_sim_material.set_shader_parameter("time_step", get_param_value("speed"))
	_sim_material.set_shader_parameter("steps_per_frame", get_param_value("steps_per_frame"))
	_sim_material.set_shader_parameter("seed_pos", get_param_value("seed_pos"))
	_sim_material.set_shader_parameter("seed_radius", get_param_value("seed_radius"))
	_sim_material.set_shader_parameter("seed_amount", get_param_value("seed_amount"))
	_sim_material.set_shader_parameter("add_seed", get_param_value("add_seed"))
	_sim_material.set_shader_parameter("reset", _needs_reset)

	# Seed input texture
	var seed_in: GNTextureData = _get_input_top(inputs, 0)
	if seed_in != null and seed_in.texture != null:
		_sim_material.set_shader_parameter("seed_texture", seed_in.texture)
		_sim_material.set_shader_parameter("use_seed_texture", true)
	else:
		_sim_material.set_shader_parameter("use_seed_texture", false)

	# --- Render uniforms ---
	_render_material.set_shader_parameter("sim_texture", _sim_viewport.get_texture())
	_render_material.set_shader_parameter("color_mode", get_param_value("color_mode"))
	var ca: Color = get_param_value("color_a")
	var cb: Color = get_param_value("color_b")
	_render_material.set_shader_parameter("color_a", Vector3(ca.r, ca.g, ca.b))
	_render_material.set_shader_parameter("color_b", Vector3(cb.r, cb.g, cb.b))
	_render_material.set_shader_parameter("brightness", get_param_value("brightness"))
	_render_material.set_shader_parameter("invert", get_param_value("invert"))

	if _needs_reset:
		_needs_reset = false

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Apply quick presets (f, k, speed values for common patterns).
func _apply_preset(preset_idx: int) -> void:
	match preset_idx:
		1:  # Mitosis
			set_param_value("feed_rate", 0.0367)
			set_param_value("kill_rate", 0.0649)
			set_param_value("speed", 1.0)
		2:  # Coral
			set_param_value("feed_rate", 0.0545)
			set_param_value("kill_rate", 0.062)
			set_param_value("speed", 1.0)
		3:  # Maze
			set_param_value("feed_rate", 0.029)
			set_param_value("kill_rate", 0.057)
			set_param_value("speed", 1.0)
		4:  # Spots
			set_param_value("feed_rate", 0.035)
			set_param_value("kill_rate", 0.065)
			set_param_value("speed", 1.0)
		5:  # Worms
			set_param_value("feed_rate", 0.078)
			set_param_value("kill_rate", 0.061)
			set_param_value("speed", 1.0)
		6:  # Waves
			set_param_value("feed_rate", 0.014)
			set_param_value("kill_rate", 0.054)
			set_param_value("speed", 1.5)
	_needs_reset = true


## Build dual viewport pipeline (called once on first cook).
func _build_pipeline(res: Vector2i) -> void:
	# --- Simulation viewport ---
	_sim_viewport = SubViewport.new()
	_sim_viewport.name = "VP_RDSim_%s" % id
	_sim_viewport.size = res
	_sim_viewport.transparent_bg = false
	_sim_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sim_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_sim_viewport.disable_3d = true
	_sim_viewport.gui_disable_input = true
	add_child(_sim_viewport)

	var sim_shader: Shader = load("res://addons/gonodes/shaders/top/reaction_diffusion.gdshader")
	_sim_material = ShaderMaterial.new()
	_sim_material.shader = sim_shader

	var sim_rect := ColorRect.new()
	sim_rect.name = "SimCanvas"
	sim_rect.material = _sim_material
	_sim_viewport.add_child(sim_rect)
	sim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Render viewport ---
	_render_viewport = SubViewport.new()
	_render_viewport.name = "VP_RDRender_%s" % id
	_render_viewport.size = res
	_render_viewport.transparent_bg = false
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_render_viewport.disable_3d = true
	_render_viewport.gui_disable_input = true
	add_child(_render_viewport)

	var render_shader: Shader = load("res://addons/gonodes/shaders/top/reaction_diffusion_render.gdshader")
	_render_material = ShaderMaterial.new()
	_render_material.shader = render_shader

	var render_rect := TextureRect.new()
	render_rect.name = "RenderCanvas"
	render_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	render_rect.stretch_mode = TextureRect.STRETCH_SCALE
	render_rect.material = _render_material
	render_rect.texture = _sim_viewport.get_texture()
	_render_viewport.add_child(render_rect)
	render_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Output
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _render_viewport.get_texture()
	_cached_tex_data.viewport = _render_viewport
	_cached_tex_data.resolution = res
	_viewport = _render_viewport
