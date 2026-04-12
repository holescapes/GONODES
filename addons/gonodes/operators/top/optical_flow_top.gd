class_name OpticalFlowTOP
extends GNTopBase
## Computes optical flow (motion vectors) between the current and previous frame.
##
## Uses a Horn-Schunck GLSL fragment shader — runs on all Godot backends
## (Vulkan, OpenGL ES 3.0, WebGL2).
##
## Output encoding:
##   R = horizontal motion (0.5 = stationary, <0.5 = left, >0.5 = right)
##   G = vertical motion (0.5 = stationary, <0.5 = up, >0.5 = down)
##   B = motion magnitude (0 = still, 1 = maximum motion)
##
## For a GPU compute shader alternative, use ComputeShaderTOP with
## the optical_flow compute preset.

var _prev_viewport: SubViewport = null
var _prev_canvas: TextureRect = null
var _prev_tex_data: GNTextureData = null
var _has_prev_frame: bool = false


func _init() -> void:
	node_type = "optical_flow"
	time_dependent = true


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture (video or animated source)")
	add_output("out", GNFamily.Type.TOP, "Optical flow vectors (R=horizontal, G=vertical, B=magnitude)")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("sensitivity", 20.0, 1.0, 100.0, 0.1,
		"Sensitivity", "Motion amplification factor"))
	add_parameter(GNParameter.create_float("smoothing", 0.1, 0.001, 1.0, 0.001,
		"Smoothing", "Regularization weight (higher = smoother flow field)"))
	add_parameter(GNParameter.create_int("iterations", 4, 1, 16,
		"Iterations", "Horn-Schunck solver iterations per pixel"))
	add_parameter(GNParameter.create_color("bg_color", Color(0.5, 0.5, 0.0, 1.0),
		"Background", "Color for areas with no motion"))
	add_parameter(GNParameter.create_bool("colorize", true,
		"Colorize Background", "Blend bg_color into still areas (off = raw flow vectors)"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null or tex_in.texture == null:
		return null

	var res: Vector2i = tex_in.resolution
	var sensitivity: float = get_param_value("sensitivity")
	var smoothing: float = get_param_value("smoothing")
	var iterations: int = get_param_value("iterations")

	# Init the main shader viewport FIRST so it gets a lower child index
	# and renders before _prev_viewport (Godot renders SubViewports in
	# child-index order — the main VP must read _prev_viewport's stale
	# texture before _prev_viewport captures the current frame).
	_init_shader_viewport("res://addons/gonodes/shaders/top/optical_flow.gdshader",
		true, false, res)

	# Ensure the "previous frame" capture viewport exists (child index > main VP)
	_ensure_prev_viewport(res)

	if _viewport.size != res:
		_viewport.size = res

	# Set shader uniforms
	_material.set_shader_parameter("current_frame", tex_in.texture)
	_material.set_shader_parameter("sensitivity", sensitivity)
	_material.set_shader_parameter("smoothing", smoothing)
	_material.set_shader_parameter("iterations", iterations)
	var bg_col: Color = get_param_value("bg_color")
	_material.set_shader_parameter("bg_color", bg_col)
	_material.set_shader_parameter("use_flow_color", get_param_value("colorize"))

	# Previous frame — use the capture viewport's texture
	if _has_prev_frame and _prev_viewport != null:
		_material.set_shader_parameter("previous_frame", _prev_viewport.get_texture())
	else:
		# First frame — no previous, use current (will show zero motion)
		_material.set_shader_parameter("previous_frame", tex_in.texture)

	_cached_tex_data.resolution = res

	# After rendering the flow, copy current frame into prev_viewport
	# by setting its TextureRect to show the current input
	if _prev_canvas != null:
		_prev_canvas.texture = tex_in.texture
	_has_prev_frame = true

	return _cached_tex_data


func _ensure_prev_viewport(size: Vector2i) -> void:
	if _prev_viewport != null:
		if _prev_viewport.size != size:
			_prev_viewport.size = size
		return

	_prev_viewport = SubViewport.new()
	_prev_viewport.name = "PrevFrame"
	_prev_viewport.size = size
	_prev_viewport.transparent_bg = true
	_prev_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_prev_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	add_child(_prev_viewport)

	_prev_canvas = TextureRect.new()
	_prev_canvas.name = "PrevCanvas"
	_prev_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prev_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_prev_viewport.add_child(_prev_canvas)
	_prev_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
