class_name EnvironmentCOMP
extends GNCompBase
## Defines the rendering environment for a 3D scene — background, ambient light,
## tone mapping, and all post-processing effects (glow, SSAO, SSIL, SSR, DOF,
## adjustments, volumetric fog).
##
## Connect to a RenderTOP's COMP input alongside Geometry/Camera/Light COMPs.
## When a RenderTOP detects an EnvironmentCOMP upstream, it uses this environment
## instead of its built-in fallback, giving you full control over the look.
##
## Separating environment from rendering allows:
##   • One environment shared across multiple RenderTOPs (beauty + AOV passes)
##   • CHOP-animated post-processing parameters (pulse glow, fog ramp, etc.)
##   • Cleaner networks — rendering params vs. look params are distinct nodes
##   • Easy A/B comparison by switching EnvironmentCOMP connections


var _environment: Environment = null
var _world_env_node: WorldEnvironment = null


func _init() -> void:
	node_type = "environment"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.COMP, "Environment component")


func _init_parameters() -> void:
	# ── Background ───────────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("bg_mode",
		PackedStringArray(["Color", "Sky", "Canvas", "Keep"]), 0,
		"Background", "Background mode"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.1, 0.1, 0.12),
		"BG Color", "Background clear color (Color mode)"))
	add_parameter(GNParameter.create_float("bg_energy", 1.0, 0.0, 16.0, 0.05,
		"BG Energy", "Background energy multiplier"))

	# ── Ambient Light ────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ambient_enabled", true,
		"Ambient Light", "Enable ambient light"))
	add_parameter(GNParameter.create_color("ambient_color", Color(0.3, 0.3, 0.4),
		"Ambient Color", "Ambient light color"))
	add_parameter(GNParameter.create_float("ambient_energy", 0.3, 0.0, 4.0, 0.05,
		"Ambient Energy", "Ambient light intensity"))

	# ── Tonemap ──────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_enum("tonemap_mode",
		PackedStringArray(["Linear", "Reinhard", "Filmic", "ACES"]), 3,
		"Tonemap", "Tone mapping algorithm"))
	add_parameter(GNParameter.create_float("tonemap_exposure", 1.0, 0.1, 8.0, 0.05,
		"Exposure", "Overall exposure multiplier"))
	add_parameter(GNParameter.create_float("tonemap_white", 1.0, 0.1, 16.0, 0.1,
		"White Point", "White reference point for tone mapping"))

	# ── Glow (Bloom) ────────────────────────────────────────────────────
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

	# ── SSAO ─────────────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("ssao_enabled", false,
		"SSAO", "Enable screen-space ambient occlusion"))
	add_parameter(GNParameter.create_float("ssao_radius", 1.0, 0.01, 16.0, 0.1,
		"SSAO Radius", "Occlusion sampling radius"))
	add_parameter(GNParameter.create_float("ssao_intensity", 2.0, 0.0, 10.0, 0.1,
		"SSAO Intensity", "Occlusion darkening strength"))
	add_parameter(GNParameter.create_float("ssao_power", 1.5, 0.1, 10.0, 0.1,
		"SSAO Power", "Occlusion falloff exponent"))

	# ── SSIL ─────────────────────────────────────────────────────────────
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

	# ── SSR ──────────────────────────────────────────────────────────────
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

	# ── Adjustments ──────────────────────────────────────────────────────
	add_parameter(GNParameter.create_bool("adj_enabled", false,
		"Adjustments", "Enable color adjustments"))
	add_parameter(GNParameter.create_float("adj_brightness", 1.0, 0.01, 4.0, 0.01,
		"Brightness", "Image brightness multiplier"))
	add_parameter(GNParameter.create_float("adj_contrast", 1.0, 0.01, 4.0, 0.01,
		"Contrast", "Image contrast"))
	add_parameter(GNParameter.create_float("adj_saturation", 1.0, 0.0, 4.0, 0.01,
		"Saturation", "Color saturation"))

	# ── Volumetric Fog ───────────────────────────────────────────────────
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


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_environment()
	_apply_background()
	_apply_ambient()
	_apply_tonemap()
	_apply_glow()
	_apply_ssao()
	_apply_ssil()
	_apply_ssr()
	_apply_adjustments()
	_apply_fog()

	# COMPs return null — RenderTOP discovers EnvironmentCOMP by typed check
	# on the upstream node object, not via cook output data.
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Environment API — accessed by RenderTOP
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the Environment resource. RenderTOP assigns this to its WorldEnvironment.
func get_environment() -> Environment:
	_ensure_environment()
	return _environment


## Returns the WorldEnvironment node.  RenderTOP can reparent this into its
## SubViewport instead of creating its own.
func get_world_environment_node() -> WorldEnvironment:
	_ensure_environment()
	return _world_env_node


# ═══════════════════════════════════════════════════════════════════════════════
# Internals
# ═══════════════════════════════════════════════════════════════════════════════

func _ensure_environment() -> void:
	if _environment == null:
		_environment = Environment.new()
	if _world_env_node == null:
		_world_env_node = WorldEnvironment.new()
		_world_env_node.name = "EnvCOMP_%s" % id
		_world_env_node.environment = _environment


func _apply_background() -> void:
	var mode: int = get_param_value("bg_mode")
	match mode:
		0: _environment.background_mode = Environment.BG_COLOR
		1: _environment.background_mode = Environment.BG_SKY
		2: _environment.background_mode = Environment.BG_CANVAS
		3: _environment.background_mode = Environment.BG_KEEP
	_environment.background_color = get_param_value("bg_color")
	_environment.background_energy_multiplier = get_param_value("bg_energy")


func _apply_ambient() -> void:
	var enabled: bool = get_param_value("ambient_enabled")
	if enabled:
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_environment.ambient_light_color = get_param_value("ambient_color")
		_environment.ambient_light_energy = get_param_value("ambient_energy")
	else:
		_environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED


func _apply_tonemap() -> void:
	_environment.tonemap_mode = get_param_value("tonemap_mode")
	_environment.tonemap_exposure = get_param_value("tonemap_exposure")
	_environment.tonemap_white = get_param_value("tonemap_white")


func _apply_glow() -> void:
	var on: bool = get_param_value("glow_enabled")
	_environment.glow_enabled = on
	if not on:
		return
	_environment.glow_intensity = get_param_value("glow_intensity")
	_environment.glow_strength = get_param_value("glow_strength")
	_environment.glow_bloom = get_param_value("glow_bloom")
	_environment.glow_hdr_threshold = get_param_value("glow_hdr_threshold")
	var blend: int = get_param_value("glow_blend_mode")
	match blend:
		0: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		1: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
		2: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		3: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_REPLACE
		4: _environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_MIX


func _apply_ssao() -> void:
	var on: bool = get_param_value("ssao_enabled")
	_environment.ssao_enabled = on
	if not on:
		return
	_environment.ssao_radius = get_param_value("ssao_radius")
	_environment.ssao_intensity = get_param_value("ssao_intensity")
	_environment.ssao_power = get_param_value("ssao_power")


func _apply_ssil() -> void:
	var on: bool = get_param_value("ssil_enabled")
	_environment.ssil_enabled = on
	if not on:
		return
	_environment.ssil_radius = get_param_value("ssil_radius")
	_environment.ssil_intensity = get_param_value("ssil_intensity")
	_environment.ssil_sharpness = get_param_value("ssil_sharpness")
	_environment.ssil_normal_rejection = get_param_value("ssil_normal_rejection")


func _apply_ssr() -> void:
	var on: bool = get_param_value("ssr_enabled")
	_environment.ssr_enabled = on
	if not on:
		return
	_environment.ssr_max_steps = get_param_value("ssr_max_steps")
	_environment.ssr_fade_in = get_param_value("ssr_fade_in")
	_environment.ssr_fade_out = get_param_value("ssr_fade_out")
	_environment.ssr_depth_tolerance = get_param_value("ssr_depth_tolerance")


func _apply_adjustments() -> void:
	var on: bool = get_param_value("adj_enabled")
	_environment.adjustment_enabled = on
	if not on:
		return
	_environment.adjustment_brightness = get_param_value("adj_brightness")
	_environment.adjustment_contrast = get_param_value("adj_contrast")
	_environment.adjustment_saturation = get_param_value("adj_saturation")


func _apply_fog() -> void:
	var on: bool = get_param_value("fog_enabled")
	_environment.volumetric_fog_enabled = on
	if not on:
		return
	_environment.volumetric_fog_density = get_param_value("fog_density")
	_environment.volumetric_fog_albedo = get_param_value("fog_albedo")
	_environment.volumetric_fog_emission = get_param_value("fog_emission")
	_environment.volumetric_fog_emission_energy = get_param_value("fog_emission_energy")
	_environment.volumetric_fog_length = get_param_value("fog_length")


## Override cleanup — free the Environment resource and WorldEnvironment node.
func destroy_scene_node() -> void:
	if _world_env_node != null:
		if _world_env_node.get_parent() != null:
			_world_env_node.get_parent().remove_child(_world_env_node)
		_world_env_node.queue_free()
		_world_env_node = null
	_environment = null
	_scene_node = null


## Preview label
func update_preview_control(control: Control) -> void:
	if control is Label:
		var label: Label = control as Label
		var parts: PackedStringArray = []
		var modes: PackedStringArray = ["Color", "Sky", "Canvas", "Keep"]
		parts.append("bg: %s" % modes[get_param_value("bg_mode")])
		if get_param_value("glow_enabled"):
			parts.append("glow")
		if get_param_value("ssao_enabled"):
			parts.append("ssao")
		if get_param_value("fog_enabled"):
			parts.append("fog")
		label.text = ", ".join(parts)


func render_for_viewer(viewer, port_index: int = 0) -> void:
	var bg_modes := ["Color", "Sky", "Canvas", "Keep"]
	var tonemap_modes := ["Linear", "Reinhard", "Filmic", "ACES"]
	var bg_mode: String = bg_modes[get_param_value("bg_mode")]
	var tm_mode: String = tonemap_modes[get_param_value("tonemap_mode")]
	var exposure: float = get_param_value("tonemap_exposure")
	var effects: PackedStringArray = []
	if get_param_value("glow_enabled"): effects.append("Glow (%.2f)" % get_param_value("glow_intensity"))
	if get_param_value("ssao_enabled"): effects.append("SSAO")
	if get_param_value("ssil_enabled"): effects.append("SSIL")
	if get_param_value("ssr_enabled"): effects.append("SSR")
	if get_param_value("adj_enabled"): effects.append("Adjustments")
	if get_param_value("fog_enabled"): effects.append("Volumetric Fog")
	var effects_str: String = ", ".join(effects) if effects.size() > 0 else "None"
	var ambient_str := ""
	if get_param_value("ambient_enabled"):
		var ac: Color = get_param_value("ambient_color")
		ambient_str = "Ambient: (%.2f, %.2f, %.2f) x %.2f" % [ac.r, ac.g, ac.b, get_param_value("ambient_energy")]
	else:
		ambient_str = "Ambient: Off"
	var text := "Background: %s\nTonemap: %s  Exposure: %.2f\n%s\nEffects: %s" % [
		bg_mode, tm_mode, exposure, ambient_str, effects_str]
	viewer.set_info(text, "EnvironmentCOMP")
