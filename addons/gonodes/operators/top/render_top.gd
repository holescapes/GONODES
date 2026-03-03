class_name RenderTOP
extends GNTopBase
## Renders a 3D scene to a texture — the bridge from COMPs back to the TOP pipeline.
##
## Takes COMP inputs (GeometryCOMP, CameraCOMP, LightCOMP) and renders them
## into a SubViewport with 3D rendering enabled, producing a GNTextureData output.
##
## Architecture:
##   SOP → GeometryCOMP → RenderTOP → (texture output to other TOPs)
##              ↑              ↑
##          CameraCOMP    LightCOMP
##
## Uses Godot's native 3D renderer (Forward+) via SubViewport for full PBR,
## shadows, reflections, and all built-in rendering features.

var _environment: Environment = null
var _world_env: WorldEnvironment = null

## Track which scene nodes are currently in the viewport
var _managed_children: Array[Node3D] = []


func _init() -> void:
	node_type = "render"
	time_dependent = true
	node_description = "Renders a 3D COMP scene into a 2D texture with integrated post-processing."


func _init_ports() -> void:
	# Dynamic-input COMP — accepts geometry, camera, lights on numbered ports
	_enable_dynamic_inputs(GNFamily.Type.COMP, "comp", "COMP Input")
	add_output("out", GNFamily.Type.TOP, "Rendered 3D scene texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(1280, 720), "Resolution", "Render resolution"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.1, 0.1, 0.12), "Background Color", "Background clear color"))
	add_parameter(GNParameter.create_bool("transparent_bg", false, "Transparent BG", "Use transparent background"))
	add_parameter(GNParameter.create_bool("use_environment", true, "Use Environment", "Enable environment lighting"))
	add_parameter(GNParameter.create_float("ambient_energy", 0.3, 0.0, 4.0, 0.05, "Ambient Energy", "Ambient light intensity"))
	add_parameter(GNParameter.create_color("ambient_color", Color(0.3, 0.3, 0.4), "Ambient Color", "Ambient light color"))
	add_parameter(GNParameter.create_enum("anti_aliasing",
		PackedStringArray(["Off", "2x MSAA", "4x MSAA", "8x MSAA"]), 2, "Anti-Aliasing", "MSAA quality level"))
	# Shadow quality
	add_parameter(GNParameter.create_enum("shadow_atlas_size",
		PackedStringArray(["1024", "2048", "4096", "8192"]), 2,
		"Shadow Atlas", "Positional shadow atlas resolution (Omni/Spot)"))
	add_parameter(GNParameter.create_enum("dir_shadow_size",
		PackedStringArray(["1024", "2048", "4096", "8192"]), 2,
		"Dir Shadow Size", "Directional shadow map resolution"))
	add_parameter(GNParameter.create_enum("shadow_filter",
		PackedStringArray(["Hard", "Soft Low", "Soft Medium", "Soft High", "Soft Ultra"]), 2,
		"Shadow Filter", "Shadow filter quality (PCF)"))

	# ── Post-Processing: Tonemap ─────────────────────────────────────────
	add_parameter(GNParameter.create_enum("tonemap_mode",
		PackedStringArray(["Linear", "Reinhard", "Filmic", "ACES"]), 3,
		"Tonemap", "Tone mapping algorithm"))
	add_parameter(GNParameter.create_float("tonemap_exposure", 1.0, 0.1, 8.0, 0.05,
		"Exposure", "Overall exposure multiplier"))
	add_parameter(GNParameter.create_float("tonemap_white", 1.0, 0.1, 16.0, 0.1,
		"White Point", "White reference point for tone mapping"))

	# ── Post-Processing: Glow (Bloom) ───────────────────────────────────
	add_parameter(GNParameter.create_bool("glow_enabled", false,
		"Glow", "Enable glow/bloom post-processing"))
	add_parameter(GNParameter.create_float("glow_intensity", 0.8, 0.0, 4.0, 0.05,
		"Glow Intensity", "Overall glow strength"))
	add_parameter(GNParameter.create_float("glow_strength", 1.0, 0.0, 2.0, 0.05,
		"Glow Strength", "Per-level glow contribution"))
	add_parameter(GNParameter.create_float("glow_bloom", 0.0, 0.0, 1.0, 0.01,
		"Glow Bloom", "Screen-wide bloom amount (softens entire image)"))
	add_parameter(GNParameter.create_float("glow_hdr_threshold", 1.0, 0.0, 4.0, 0.05,
		"HDR Threshold", "Brightness threshold for glow (lower = more glow)"))
	add_parameter(GNParameter.create_enum("glow_blend_mode",
		PackedStringArray(["Additive", "Screen", "Softlight", "Replace", "Mix"]), 0,
		"Glow Blend", "How glow is composited onto the image"))

	# ── Post-Processing: Depth of Field ─────────────────────────────────
	add_parameter(GNParameter.create_bool("dof_far_enabled", false,
		"DOF Far", "Enable far depth-of-field blur"))
	add_parameter(GNParameter.create_float("dof_far_distance", 10.0, 0.1, 200.0, 0.5,
		"Far Distance", "Focus distance for far DOF"))
	add_parameter(GNParameter.create_float("dof_far_transition", 5.0, 0.1, 50.0, 0.5,
		"Far Transition", "Transition region width for far DOF"))
	add_parameter(GNParameter.create_bool("dof_near_enabled", false,
		"DOF Near", "Enable near depth-of-field blur"))
	add_parameter(GNParameter.create_float("dof_near_distance", 2.0, 0.1, 50.0, 0.1,
		"Near Distance", "Focus distance for near DOF"))
	add_parameter(GNParameter.create_float("dof_near_transition", 1.0, 0.1, 20.0, 0.1,
		"Near Transition", "Transition region width for near DOF"))
	add_parameter(GNParameter.create_float("dof_bokeh_size", 4.0, 0.5, 10.0, 0.1,
		"Bokeh Size", "Blur disc radius for DOF"))
	add_parameter(GNParameter.create_enum("dof_bokeh_shape",
		PackedStringArray(["Box", "Hexagon", "Circle"]), 2,
		"Bokeh Shape", "Shape of the depth-of-field bokeh"))

	# ── Post-Processing: SSAO ────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ssao_enabled", false,
		"SSAO", "Enable screen-space ambient occlusion"))
	add_parameter(GNParameter.create_float("ssao_radius", 1.0, 0.01, 16.0, 0.1,
		"SSAO Radius", "Occlusion sampling radius"))
	add_parameter(GNParameter.create_float("ssao_intensity", 2.0, 0.0, 10.0, 0.1,
		"SSAO Intensity", "Occlusion darkening strength"))
	add_parameter(GNParameter.create_float("ssao_power", 1.5, 0.1, 10.0, 0.1,
		"SSAO Power", "Occlusion falloff exponent"))

	# ── Post-Processing: SSIL ────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ssil_enabled", false,
		"SSIL", "Enable screen-space indirect lighting"))
	add_parameter(GNParameter.create_float("ssil_radius", 5.0, 0.01, 16.0, 0.1,
		"SSIL Radius", "Indirect light sampling radius"))
	add_parameter(GNParameter.create_float("ssil_intensity", 1.0, 0.0, 10.0, 0.1,
		"SSIL Intensity", "Indirect light contribution strength"))
	add_parameter(GNParameter.create_float("ssil_sharpness", 0.98, 0.0, 1.0, 0.01,
		"SSIL Sharpness", "Edge-aware blur sharpness"))
	add_parameter(GNParameter.create_float("ssil_normal_rejection", 1.0, 0.0, 1.0, 0.01,
		"SSIL Normal Rej", "Reject samples with different normals"))

	# ── Post-Processing: SSR ─────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ssr_enabled", false,
		"SSR", "Enable screen-space reflections"))
	add_parameter(GNParameter.create_int("ssr_max_steps", 64, 1, 512,
		"SSR Steps", "Maximum ray march steps"))
	add_parameter(GNParameter.create_float("ssr_fade_in", 0.15, 0.0, 2.0, 0.01,
		"SSR Fade In", "Distance at which reflections fade in"))
	add_parameter(GNParameter.create_float("ssr_fade_out", 2.0, 0.0, 8.0, 0.1,
		"SSR Fade Out", "Distance at which reflections fade out"))
	add_parameter(GNParameter.create_float("ssr_depth_tolerance", 0.2, 0.01, 4.0, 0.01,
		"SSR Depth Tol", "Depth comparison tolerance for ray hits"))

	# ── Post-Processing: Adjustments ─────────────────────────────────────
	add_parameter(GNParameter.create_bool("adj_enabled", false,
		"Adjustments", "Enable color adjustments"))
	add_parameter(GNParameter.create_float("adj_brightness", 1.0, 0.01, 4.0, 0.01,
		"Brightness", "Image brightness multiplier"))
	add_parameter(GNParameter.create_float("adj_contrast", 1.0, 0.01, 4.0, 0.01,
		"Contrast", "Image contrast"))
	add_parameter(GNParameter.create_float("adj_saturation", 1.0, 0.0, 4.0, 0.01,
		"Saturation", "Color saturation"))

	# ── Post-Processing: Volumetric Fog ──────────────────────────────────
	add_parameter(GNParameter.create_bool("fog_enabled", false,
		"Volumetric Fog", "Enable volumetric fog"))
	add_parameter(GNParameter.create_float("fog_density", 0.05, 0.0, 1.0, 0.005,
		"Fog Density", "Base fog density"))
	add_parameter(GNParameter.create_color("fog_albedo", Color(1.0, 1.0, 1.0),
		"Fog Albedo", "Fog scatter colour"))
	add_parameter(GNParameter.create_color("fog_emission", Color(0.0, 0.0, 0.0),
		"Fog Emission", "Fog self-emission colour"))
	add_parameter(GNParameter.create_float("fog_emission_energy", 1.0, 0.0, 16.0, 0.1,
		"Fog Em. Energy", "Fog emission intensity"))
	add_parameter(GNParameter.create_float("fog_length", 64.0, 1.0, 1024.0, 1.0,
		"Fog Length", "Volumetric fog distance"))


func _cook(inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var res: Vector2i = get_param_value("resolution")
	var bg_color: Color = get_param_value("bg_color")
	var transparent: bool = get_param_value("transparent_bg")
	var use_env: bool = get_param_value("use_environment")
	var aa_mode: int = get_param_value("anti_aliasing")

	# Update viewport settings
	if _viewport.size != res:
		_viewport.size = res

	_viewport.transparent_bg = transparent

	# Anti-aliasing
	match aa_mode:
		0: _viewport.msaa_3d = Viewport.MSAA_DISABLED
		1: _viewport.msaa_3d = Viewport.MSAA_2X
		2: _viewport.msaa_3d = Viewport.MSAA_4X
		3: _viewport.msaa_3d = Viewport.MSAA_8X

	# Shadow atlas (positional lights: Omni/Spot)
	var atlas_idx: int = get_param_value("shadow_atlas_size")
	var atlas_sizes: Array[int] = [1024, 2048, 4096, 8192]
	_viewport.positional_shadow_atlas_size = atlas_sizes[atlas_idx]

	# Directional shadow size
	var dir_idx: int = get_param_value("dir_shadow_size")
	_viewport.set_meta("directional_shadow_size", atlas_sizes[dir_idx])

	# Shadow filter quality
	var filter_idx: int = get_param_value("shadow_filter")
	match filter_idx:
		0: _viewport.positional_shadow_atlas_16_bits = false
		1: _viewport.positional_shadow_atlas_16_bits = true

	# Update environment
	if _environment != null:
		_environment.background_mode = Environment.BG_COLOR
		_environment.background_color = bg_color
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if use_env else Environment.AMBIENT_SOURCE_DISABLED
		_environment.ambient_light_color = get_param_value("ambient_color")
		_environment.ambient_light_energy = get_param_value("ambient_energy")

	# ── Post-Processing ──────────────────────────────────────────────────
	_apply_post_processing()

	# Remove previously managed children that are no longer connected
	_clear_managed_children()

	# Scan inputs for COMP nodes and add their 3D nodes to the viewport
	# The cook engine passes upstream cached_output via inputs, but we need
	# to access the actual COMP nodes to get their MeshInstance3D/Camera3D/Light3D.
	_populate_scene_from_network()

	# Apply DOF after scene population so we target the active camera
	_apply_dof_to_active_camera()

	# Update output
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Lazily creates the 3D SubViewport and environment.
func _setup_viewport() -> void:
	if _viewport != null:
		return

	_viewport = _create_viewport("VP3D_%s" % id, get_param_value("resolution"), false, false)
	_viewport.own_world_3d = true  # Isolated 3D world

	# Create environment for the scene
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.1, 0.1, 0.12)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.3, 0.3, 0.4)
	_environment.ambient_light_energy = 0.3

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnv"
	_world_env.environment = _environment
	_viewport.add_child(_world_env)

	# Create output texture data
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size


## Populates the 3D viewport with scene nodes from connected COMPs.
## Iterates connections sorted by input port index for deterministic ordering.
func _populate_scene_from_network() -> void:
	if _viewport == null:
		return

	# Find the cook engine to get network reference
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return

	var network: GNNetwork = engine.network
	var has_camera: bool = false

	# Sort connections by input port index for deterministic scene order
	var conns: Array = network.get_input_connections(id).duplicate()
	conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)

	# Find all COMP nodes connected to this RenderTOP's inputs
	for conn in conns:
		var upstream_node: GNNode = network.nodes.get(conn.from_node, null)
		if upstream_node == null:
			continue

		if upstream_node is MergeCOMP:
			var group_node: Node3D = (upstream_node as MergeCOMP).get_group_node()
			if group_node != null:
				_adopt_scene_node(group_node)

		elif upstream_node is GeometryCOMP:
			var mesh_inst: MeshInstance3D = (upstream_node as GeometryCOMP).get_mesh_instance()
			if mesh_inst != null:
				_adopt_scene_node(mesh_inst)

		elif upstream_node is CameraCOMP:
			var camera: Camera3D = (upstream_node as CameraCOMP).get_camera()
			if camera != null:
				_adopt_scene_node(camera)
				camera.current = true
				has_camera = true

		elif upstream_node is LightCOMP:
			var light: Light3D = (upstream_node as LightCOMP).get_light()
			if light != null:
				_adopt_scene_node(light)

	# If no camera COMP is connected, create a default camera
	if not has_camera:
		_ensure_default_camera()


## Adds a 3D node to the viewport if not already there.
func _adopt_scene_node(node_3d: Node3D) -> void:
	if node_3d.get_parent() == _viewport:
		return  # Already in our viewport
	if node_3d.get_parent() != null:
		node_3d.get_parent().remove_child(node_3d)
	_viewport.add_child(node_3d)
	_managed_children.append(node_3d)


## Removes all managed children from the viewport before re-populating.
func _clear_managed_children() -> void:
	for child in _managed_children:
		if child != null and is_instance_valid(child) and child.get_parent() == _viewport:
			_viewport.remove_child(child)
	_managed_children.clear()


## Creates a default camera if none is provided by a CameraCOMP.
var _default_camera: Camera3D = null

func _ensure_default_camera() -> void:
	if _default_camera == null:
		_default_camera = Camera3D.new()
		_default_camera.name = "DefaultCam"
		_default_camera.position = Vector3(0, 1.5, 3.0)
		_default_camera.rotation_degrees = Vector3(-15, 0, 0)
		_default_camera.fov = 75.0
	if _default_camera.get_parent() != _viewport:
		if _default_camera.get_parent() != null:
			_default_camera.get_parent().remove_child(_default_camera)
		_viewport.add_child(_default_camera)
	_default_camera.current = true
	_managed_children.append(_default_camera)


# ═══════════════════════════════════════════════════════════════════════════════
# Post-Processing
# ═══════════════════════════════════════════════════════════════════════════════

## Applies all post-processing parameters to the viewport's Environment and
## active camera — integrated directly into the render operator.
## Early-exits when every toggle is off and tonemap is at defaults, so a
## vanilla RenderTOP pays zero post-processing overhead.
func _apply_post_processing() -> void:
	if _environment == null:
		return

	# Fast path: check if ANY post-processing feature is active.
	var glow_on:  bool = get_param_value("glow_enabled")
	var ssao_on:  bool = get_param_value("ssao_enabled")
	var ssil_on:  bool = get_param_value("ssil_enabled")
	var ssr_on:   bool = get_param_value("ssr_enabled")
	var adj_on:   bool = get_param_value("adj_enabled")
	var fog_on:   bool = get_param_value("fog_enabled")
	var tmap_mode: int = get_param_value("tonemap_mode")  # 0 = Linear (engine default)
	var tmap_exp: float = get_param_value("tonemap_exposure")
	var tmap_wht: float = get_param_value("tonemap_white")

	var any_active: bool = (
		glow_on or ssao_on or ssil_on or ssr_on or adj_on or fog_on
		or tmap_mode != 0 or not is_equal_approx(tmap_exp, 1.0)
		or not is_equal_approx(tmap_wht, 1.0)
	)

	if not any_active:
		# Ensure everything is explicitly off (handles toggling features off
		# after they were previously enabled).
		_environment.tonemap_mode = 0  # Linear (default)
		_environment.glow_enabled = false
		_environment.ssao_enabled = false
		_environment.ssil_enabled = false
		_environment.ssr_enabled = false
		_environment.adjustment_enabled = false
		_environment.volumetric_fog_enabled = false
		return

	# ── Tonemap ──────────────────────────────────────────────────────────
	_environment.tonemap_mode = tmap_mode
	_environment.tonemap_exposure = tmap_exp
	_environment.tonemap_white = tmap_wht

	# ── Glow ─────────────────────────────────────────────────────────────
	_environment.glow_enabled = glow_on
	if _environment.glow_enabled:
		_environment.glow_intensity = get_param_value("glow_intensity")
		_environment.glow_strength = get_param_value("glow_strength")
		_environment.glow_bloom = get_param_value("glow_bloom")
		_environment.glow_hdr_threshold = get_param_value("glow_hdr_threshold")
		var glow_blend: int = get_param_value("glow_blend_mode")
		match glow_blend:
			0: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
			1: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
			2: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			3: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_REPLACE
			4: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX

	# ── SSAO ─────────────────────────────────────────────────────────────
	_environment.ssao_enabled = get_param_value("ssao_enabled")
	if _environment.ssao_enabled:
		_environment.ssao_radius = get_param_value("ssao_radius")
		_environment.ssao_intensity = get_param_value("ssao_intensity")
		_environment.ssao_power = get_param_value("ssao_power")

	# ── SSIL ─────────────────────────────────────────────────────────────
	_environment.ssil_enabled = get_param_value("ssil_enabled")
	if _environment.ssil_enabled:
		_environment.ssil_radius = get_param_value("ssil_radius")
		_environment.ssil_intensity = get_param_value("ssil_intensity")
		_environment.ssil_sharpness = get_param_value("ssil_sharpness")
		_environment.ssil_normal_rejection = get_param_value("ssil_normal_rejection")

	# ── SSR ──────────────────────────────────────────────────────────────
	_environment.ssr_enabled = get_param_value("ssr_enabled")
	if _environment.ssr_enabled:
		_environment.ssr_max_steps = get_param_value("ssr_max_steps")
		_environment.ssr_fade_in = get_param_value("ssr_fade_in")
		_environment.ssr_fade_out = get_param_value("ssr_fade_out")
		_environment.ssr_depth_tolerance = get_param_value("ssr_depth_tolerance")

	# ── Adjustments ──────────────────────────────────────────────────────
	_environment.adjustment_enabled = get_param_value("adj_enabled")
	if _environment.adjustment_enabled:
		_environment.adjustment_brightness = get_param_value("adj_brightness")
		_environment.adjustment_contrast = get_param_value("adj_contrast")
		_environment.adjustment_saturation = get_param_value("adj_saturation")

	# ── Volumetric Fog ───────────────────────────────────────────────────
	_environment.volumetric_fog_enabled = get_param_value("fog_enabled")
	if _environment.volumetric_fog_enabled:
		_environment.volumetric_fog_density = get_param_value("fog_density")
		_environment.volumetric_fog_albedo = get_param_value("fog_albedo")
		_environment.volumetric_fog_emission = get_param_value("fog_emission")
		_environment.volumetric_fog_emission_energy = get_param_value("fog_emission_energy")
		_environment.volumetric_fog_length = get_param_value("fog_length")


## Applies DOF parameters to whatever camera is currently active in the viewport.
## Called after _populate_scene_from_network so the active camera is known.
## Early-exits when both DOF toggles are off.
func _apply_dof_to_active_camera() -> void:
	var dof_far: bool = get_param_value("dof_far_enabled")
	var dof_near: bool = get_param_value("dof_near_enabled")

	# Fast path: no DOF requested — skip camera lookup entirely.
	if not dof_far and not dof_near:
		return

	var active_cam: Camera3D = _find_active_camera()
	if active_cam == null:
		return

	# Ensure camera has CameraAttributesPractical for DOF
	if active_cam.attributes == null or not (active_cam.attributes is CameraAttributesPractical):
		active_cam.attributes = CameraAttributesPractical.new()

	var attrs: CameraAttributesPractical = active_cam.attributes as CameraAttributesPractical

	# ── DOF Far ──────────────────────────────────────────────────────────
	attrs.dof_blur_far_enabled = dof_far
	if dof_far:
		attrs.dof_blur_far_distance = get_param_value("dof_far_distance")
		attrs.dof_blur_far_transition = get_param_value("dof_far_transition")

	# ── DOF Near ─────────────────────────────────────────────────────────
	attrs.dof_blur_near_enabled = dof_near
	if dof_near:
		attrs.dof_blur_near_distance = get_param_value("dof_near_distance")
		attrs.dof_blur_near_transition = get_param_value("dof_near_transition")

	# ── DOF shared ───────────────────────────────────────────────────────
	if dof_far or dof_near:
		attrs.dof_blur_amount = get_param_value("dof_bokeh_size")
		var bokeh_shape: int = get_param_value("dof_bokeh_shape")
		match bokeh_shape:
			0: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_BOX)
			1: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_HEXAGON)
			2: RenderingServer.camera_attributes_set_dof_blur_bokeh_shape(RenderingServer.DOF_BOKEH_CIRCLE)


## Finds the active Camera3D in the viewport (from CameraCOMP or the default).
func _find_active_camera() -> Camera3D:
	if _viewport == null:
		return null
	for child in _viewport.get_children():
		if child is Camera3D and (child as Camera3D).current:
			return child as Camera3D
	return null