class_name Fluid2DTOP
extends GNTopBase
## 2D Navier-Stokes fluid simulation rendered as a texture.
##
## Uses a feedback loop (SCREEN_TEXTURE) to maintain velocity and density
## across frames.  Velocity is stored in RG, density in B.  A second
## SubViewport renders the simulation buffer as a colorized output.
##
## Features: semi-Lagrangian advection, vorticity confinement, configurable
## emitter, optional dye source input, and pressure correction.
##
## TouchDesigner equivalent: GLSL Multi-Pass TOP / Stoner Fluid.

var _sim_viewport: SubViewport = null
var _sim_material: ShaderMaterial = null
var _render_viewport: SubViewport = null
var _render_material: ShaderMaterial = null
var _last_res: Vector2i = Vector2i.ZERO
var _needs_reset: bool = true


func _init() -> void:
	node_type = "fluid_2d"
	time_dependent = true
	node_description = "2D fluid simulation with advection, vorticity, and dye injection."


func _init_ports() -> void:
	add_input("dye", GNFamily.Type.TOP, true, "Optional dye source texture")
	add_output("out", GNFamily.Type.TOP, "Rendered fluid texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512),
		"Resolution", "Output texture resolution"))
	add_parameter(GNParameter.create_vector2("emitter_pos", Vector2(0.5, 0.5),
		"Emitter Pos", "Emitter position (0–1 normalized)"))
	add_parameter(GNParameter.create_vector2("emitter_dir", Vector2(0.0, -1.0),
		"Emitter Dir", "Force direction vector"))
	add_parameter(GNParameter.create_float("emitter_radius", 0.06, 0.01, 0.5, 0.01,
		"Emitter Radius", "Emitter radius (normalized)"))
	add_parameter(GNParameter.create_float("emitter_force", 1.0, 0.0, 10.0, 0.1,
		"Force", "Emitter force strength"))
	add_parameter(GNParameter.create_float("emitter_dye", 1.0, 0.0, 5.0, 0.1,
		"Dye Amount", "Dye injection amount"))
	add_parameter(GNParameter.create_bool("enable_emitter", true,
		"Emitter On", "Enable/disable the emitter"))
	add_parameter(GNParameter.create_float("velocity_dissipation", 0.995, 0.9, 1.0, 0.001,
		"Vel Dissipation", "Velocity decay per step"))
	add_parameter(GNParameter.create_float("density_dissipation", 0.98, 0.9, 1.0, 0.001,
		"Density Dissipation", "Density decay per step"))
	add_parameter(GNParameter.create_float("vorticity", 0.3, 0.0, 2.0, 0.01,
		"Vorticity", "Vorticity confinement strength"))
	add_parameter(GNParameter.create_float("pressure", 16.0, 0.0, 32.0, 1.0,
		"Pressure", "Pressure correction strength"))
	add_parameter(GNParameter.create_color("dye_color_a", Color(1.0, 0.4, 0.1),
		"Dye Color A", "Primary dye color"))
	add_parameter(GNParameter.create_color("dye_color_b", Color(0.1, 0.4, 1.0),
		"Dye Color B", "Secondary dye color"))
	add_parameter(GNParameter.create_float("brightness", 1.5, 0.1, 5.0, 0.1,
		"Brightness", "Output brightness multiplier"))
	add_parameter(GNParameter.create_bool("show_velocity", false,
		"Show Velocity", "Visualize velocity field instead of density"))
	add_parameter(GNParameter.create_bool("reset", false,
		"Reset", "Clear the simulation"))


func _cook(inputs: Array[GNData]) -> GNData:
	var res: Vector2i = get_param_value("resolution")
	var do_reset: bool = get_param_value("reset")

	# Build simulation + render viewports on first cook or resolution change
	if _sim_viewport == null or _last_res != res:
		_build_pipeline(res)
		_last_res = res
		_needs_reset = true

	if do_reset:
		_needs_reset = true
		set_param_value("reset", false)

	# --- Update simulation shader uniforms ---
	_sim_material.set_shader_parameter("resolution", Vector2(res))
	_sim_material.set_shader_parameter("emitter_pos", get_param_value("emitter_pos"))
	_sim_material.set_shader_parameter("emitter_dir", get_param_value("emitter_dir"))
	_sim_material.set_shader_parameter("emitter_radius", get_param_value("emitter_radius"))
	_sim_material.set_shader_parameter("emitter_force", get_param_value("emitter_force"))
	_sim_material.set_shader_parameter("emitter_dye", get_param_value("emitter_dye"))
	_sim_material.set_shader_parameter("enable_emitter", get_param_value("enable_emitter"))
	_sim_material.set_shader_parameter("velocity_dissipation", get_param_value("velocity_dissipation"))
	_sim_material.set_shader_parameter("density_dissipation", get_param_value("density_dissipation"))
	_sim_material.set_shader_parameter("vorticity_strength", get_param_value("vorticity"))
	_sim_material.set_shader_parameter("pressure_iterations", get_param_value("pressure"))
	_sim_material.set_shader_parameter("time_val", elapsed_time)
	_sim_material.set_shader_parameter("reset", _needs_reset)

	# Handle dye input
	var dye_in: GNTextureData = _get_input_top(inputs, 0)
	if dye_in != null and dye_in.texture != null:
		_sim_material.set_shader_parameter("dye_input", dye_in.texture)
		_sim_material.set_shader_parameter("use_dye_input", true)
	else:
		_sim_material.set_shader_parameter("use_dye_input", false)

	# --- Update render shader uniforms ---
	_render_material.set_shader_parameter("sim_texture", _sim_viewport.get_texture())
	var color_a: Color = get_param_value("dye_color_a")
	var color_b: Color = get_param_value("dye_color_b")
	_render_material.set_shader_parameter("dye_color_a", Vector3(color_a.r, color_a.g, color_a.b))
	_render_material.set_shader_parameter("dye_color_b", Vector3(color_b.r, color_b.g, color_b.b))
	_render_material.set_shader_parameter("brightness", get_param_value("brightness"))
	_render_material.set_shader_parameter("show_velocity", get_param_value("show_velocity"))

	if _needs_reset:
		_needs_reset = false

	# Resize if needed
	if _sim_viewport.size != res:
		_sim_viewport.size = res
		_render_viewport.size = res

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Build the dual-viewport pipeline: sim (feedback) → render (colorize).
func _build_pipeline(res: Vector2i) -> void:
	# Clean up old viewports
	for child in get_children():
		child.queue_free()

	# --- Simulation viewport (feedback loop) ---
	_sim_viewport = SubViewport.new()
	_sim_viewport.name = "VP_Sim_%s" % id
	_sim_viewport.size = res
	_sim_viewport.transparent_bg = false
	_sim_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sim_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_sim_viewport.disable_3d = true
	_sim_viewport.gui_disable_input = true
	add_child(_sim_viewport)

	var sim_shader: Shader = load("res://addons/gonodes/shaders/top/fluid_2d.gdshader")
	_sim_material = ShaderMaterial.new()
	_sim_material.shader = sim_shader

	var sim_rect := ColorRect.new()
	sim_rect.name = "SimCanvas"
	sim_rect.material = _sim_material
	_sim_viewport.add_child(sim_rect)
	sim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Render viewport (colorize the sim buffer) ---
	_render_viewport = SubViewport.new()
	_render_viewport.name = "VP_Render_%s" % id
	_render_viewport.size = res
	_render_viewport.transparent_bg = false
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_render_viewport.disable_3d = true
	_render_viewport.gui_disable_input = true
	add_child(_render_viewport)

	var render_shader: Shader = load("res://addons/gonodes/shaders/top/fluid_2d_render.gdshader")
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

	# Output references the render viewport
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _render_viewport.get_texture()
	_cached_tex_data.viewport = _render_viewport
	_cached_tex_data.resolution = res
	_viewport = _render_viewport
