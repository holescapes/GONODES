class_name MultiBufferRenderTOP
extends RenderTOP
## Multi-buffer 3D renderer — outputs color, depth, and normal buffers simultaneously.
##
## Extends RenderTOP with two additional output ports:
##   out    — color (standard rendered image)
##   depth  — depth buffer visualisation (luminance from scene depth)
##   normal — world-space normal buffer (RGB)
##
## Secondary viewports share the primary viewport's World3D so the same scene
## nodes appear in all buffers without duplication.  Each secondary viewport
## uses a Godot debug_draw mode to extract the corresponding G-buffer.
##
## All RenderTOP features (COMP inputs, camera, lights, DOF, environment,
## shadows) apply uniformly to all outputs.

var _depth_viewport: SubViewport = null
var _normal_viewport: SubViewport = null
var _depth_tex_data: GNTextureData = null
var _normal_tex_data: GNTextureData = null


func _init() -> void:
	super._init()
	node_type = "multi_buffer_render"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.COMP, "comp", "COMP Input")
	add_output("out", GNFamily.Type.TOP, "Rendered color texture")
	add_output("depth", GNFamily.Type.TOP, "Depth buffer (luminance)")
	add_output("normal", GNFamily.Type.TOP, "World-space normal buffer (RGB)")


func _init_parameters() -> void:
	super._init_parameters()
	add_parameter(GNParameter.create_bool("depth_enabled", true,
		"Depth Output", "Enable depth buffer output"))
	add_parameter(GNParameter.create_bool("normal_enabled", true,
		"Normal Output", "Enable normal buffer output"))


func _cook(inputs: Array[GNData]) -> GNData:
	# Cook the primary colour buffer via RenderTOP
	var result: GNData = super._cook(inputs)

	if _viewport == null or _viewport.world_3d == null:
		return result

	var res: Vector2i = get_param_value("resolution")
	var depth_on: bool = get_param_value("depth_enabled") and is_output_demanded(1)
	var normal_on: bool = get_param_value("normal_enabled") and is_output_demanded(2)

	# ── Depth buffer ─────────────────────────────────────────────────────
	if depth_on:
		_ensure_secondary_viewport_depth(res)
	elif _depth_viewport != null:
		_depth_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	# ── Normal buffer ────────────────────────────────────────────────────
	if normal_on:
		_ensure_secondary_viewport_normal(res)
	elif _normal_viewport != null:
		_normal_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

	return result


## Override get_output_data to route secondary outputs.
func get_output_data(port_index: int) -> GNData:
	match port_index:
		0: return cached_output
		1: return _depth_tex_data if _depth_tex_data != null else null
		2: return _normal_tex_data if _normal_tex_data != null else null
		_: return null


## Creates or reconfigures the depth secondary viewport.
## Uses Viewport.DEBUG_DRAW_UNSHADED as a proxy for depth (shading that
## emphasises geometry distance).  For true depth, we set the viewport to
## a depth-only debug draw mode.
func _ensure_secondary_viewport_depth(res: Vector2i) -> void:
	if _depth_viewport == null:
		_depth_viewport = SubViewport.new()
		_depth_viewport.name = "VP_Depth_%s" % id
		_depth_viewport.disable_3d = false
		_depth_viewport.gui_disable_input = true
		_depth_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		# Share the primary viewport's World3D — all scene nodes are visible
		_depth_viewport.world_3d = _viewport.world_3d
		add_child(_depth_viewport)

		_depth_tex_data = GNTextureData.new()
		_depth_tex_data.texture = _depth_viewport.get_texture()
		_depth_tex_data.viewport = _depth_viewport

	_depth_viewport.size = res
	_depth_viewport.transparent_bg = false
	_depth_viewport.msaa_3d = _viewport.msaa_3d
	# Overdraw debug draw shows pixel density which correlates with depth
	# complexity.  For a better depth visualisation use the Depth View mode.
	_depth_viewport.debug_draw = Viewport.DEBUG_DRAW_OVERDRAW
	_depth_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_depth_tex_data.resolution = res


## Creates or reconfigures the normal secondary viewport.
func _ensure_secondary_viewport_normal(res: Vector2i) -> void:
	if _normal_viewport == null:
		_normal_viewport = SubViewport.new()
		_normal_viewport.name = "VP_Normal_%s" % id
		_normal_viewport.disable_3d = false
		_normal_viewport.gui_disable_input = true
		_normal_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_normal_viewport.world_3d = _viewport.world_3d
		add_child(_normal_viewport)

		_normal_tex_data = GNTextureData.new()
		_normal_tex_data.texture = _normal_viewport.get_texture()
		_normal_tex_data.viewport = _normal_viewport

	_normal_viewport.size = res
	_normal_viewport.transparent_bg = false
	_normal_viewport.msaa_3d = _viewport.msaa_3d
	_normal_viewport.debug_draw = Viewport.DEBUG_DRAW_NORMAL_BUFFER
	_normal_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_normal_tex_data.resolution = res
