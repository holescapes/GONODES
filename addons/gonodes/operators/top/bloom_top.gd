class_name BloomTOP
extends GNTopBase
## Bloom / glow effect using Dual Kawase blur.
## Pipeline: threshold → downsample chain → upsample chain → composite with original.
## Very efficient — 5 taps per downsample, 8 per upsample, no separable passes needed.

const MAX_LEVELS := 6

var _threshold_vp: SubViewport = null
var _threshold_mat: ShaderMaterial = null
var _threshold_canvas: TextureRect = null

var _down_vps: Array[SubViewport] = []
var _down_mats: Array[ShaderMaterial] = []
var _down_canvases: Array[TextureRect] = []

var _up_vps: Array[SubViewport] = []
var _up_mats: Array[ShaderMaterial] = []
var _up_canvases: Array[TextureRect] = []

var _composite_vp: SubViewport = null
var _composite_mat: ShaderMaterial = null
var _composite_canvas: TextureRect = null

var _shader_threshold: Shader = null
var _shader_down: Shader = null
var _shader_up: Shader = null
var _shader_composite: Shader = null

var _initialized: bool = false
var _last_levels: int = 0
var _pipeline_dirty: bool = false


func _init() -> void:
	node_type = "bloom"


func _init_ports() -> void:
	add_input("in", GNFamily.Type.TOP, false, "Input texture", "In")
	add_output("out", GNFamily.Type.TOP, "Bloomed texture", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("threshold", 0.8, 0.0, 5.0, 0.01, "Threshold",
		"Luminance threshold for bloom extraction"))
	add_parameter(GNParameter.create_float("knee", 0.1, 0.0, 1.0, 0.01, "Knee",
		"Soft knee width around the threshold"))
	add_parameter(GNParameter.create_float("intensity", 1.0, 0.0, 5.0, 0.01, "Intensity",
		"Bloom glow strength"))
	add_parameter(GNParameter.create_int("levels", 4, 1, MAX_LEVELS, "Levels",
		"Downsample/upsample levels (more = wider bloom)"))
	add_parameter(GNParameter.create_enum("blend",
		PackedStringArray(["Screen", "Add", "Soft Light"]), 0, "",
		"How bloom is composited with the original"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("BloomTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = tex_in.resolution
	var levels: int = get_param_value("levels")

	_setup_pipeline(res, levels)

	var threshold_val: float = get_param_value("threshold")
	var knee_val: float = get_param_value("knee")
	var intensity_val: float = get_param_value("intensity")
	var blend_val: int = get_param_value("blend")

	# ── Pass 1: Threshold ──
	_threshold_canvas.texture = tex_in.texture
	_threshold_mat.set_shader_parameter("source_tex", tex_in.texture)
	_threshold_mat.set_shader_parameter("threshold", threshold_val)
	_threshold_mat.set_shader_parameter("knee", knee_val)
	if _threshold_vp.size != res:
		_threshold_vp.size = res
		_threshold_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ── Pass 2: Downsample chain ──
	var current_tex: ViewportTexture = _threshold_vp.get_texture()
	var current_size: Vector2i = res
	for i in range(levels):
		current_size = Vector2i(maxi(current_size.x / 2, 1), maxi(current_size.y / 2, 1))
		if _down_vps[i].size != current_size:
			_down_vps[i].size = current_size
			_down_canvases[i].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_down_canvases[i].texture = current_tex
		_down_mats[i].set_shader_parameter("source_tex", current_tex)
		_down_mats[i].set_shader_parameter("texel_size",
			Vector2(1.0 / float(current_size.x), 1.0 / float(current_size.y)))
		current_tex = _down_vps[i].get_texture()

	# ── Pass 3: Upsample chain ──
	for i in range(levels - 1, -1, -1):
		var up_size: Vector2i
		if i == 0:
			up_size = res
		else:
			# Match the size of the downsample level one step above
			up_size = _down_vps[i - 1].size
		if _up_vps[i].size != up_size:
			_up_vps[i].size = up_size
			_up_canvases[i].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_up_canvases[i].texture = current_tex
		_up_mats[i].set_shader_parameter("source_tex", current_tex)
		_up_mats[i].set_shader_parameter("texel_size",
			Vector2(1.0 / float(up_size.x), 1.0 / float(up_size.y)))
		current_tex = _up_vps[i].get_texture()

	# ── Pass 4: Composite ──
	if _composite_vp.size != res:
		_composite_vp.size = res
		_composite_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The TextureRect needs a texture to draw; use the original input.
	# The shader reads original_tex and glow_tex explicitly via uniforms.
	_composite_canvas.texture = tex_in.texture
	_composite_mat.set_shader_parameter("original_tex", tex_in.texture)
	_composite_mat.set_shader_parameter("glow_tex", current_tex)
	_composite_mat.set_shader_parameter("intensity", intensity_val)
	_composite_mat.set_shader_parameter("blend_mode", blend_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data


## Override to schedule a second cook whenever the VP pipeline is rebuilt.
## On the first cook after creation/rebuild, the composite VP has never rendered
## so downstream TOPs read an empty ViewportTexture.  keep_dirty_after_cook
## forces a second cook on the next frame — by then the VPs have rendered and
## the downstream can sample valid content.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	if _pipeline_dirty:
		_pipeline_dirty = false
		# super already cleared dirty; silent re-queue (same as keep_dirty_after_cook)
		dirty = true
		_last_cook_input_hash = -1
	return result


func _setup_pipeline(res: Vector2i, levels: int) -> void:
	if _initialized and levels == _last_levels:
		return

	# Load shaders once
	if _shader_threshold == null:
		_shader_threshold = load("res://addons/gonodes/shaders/top/bloom_threshold.gdshader")
		_shader_down = load("res://addons/gonodes/shaders/top/bloom_downsample.gdshader")
		_shader_up = load("res://addons/gonodes/shaders/top/bloom_upsample.gdshader")
		_shader_composite = load("res://addons/gonodes/shaders/top/bloom.gdshader")

	# Clean up old viewports if levels changed
	if _initialized:
		_cleanup_pipeline()

	# Threshold pass
	_threshold_vp = _create_viewport("VP_threshold_%s" % id, res)
	_threshold_mat = ShaderMaterial.new()
	_threshold_mat.shader = _shader_threshold
	_threshold_canvas = TextureRect.new()
	_threshold_canvas.name = "Canvas_Threshold"
	_threshold_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_threshold_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_threshold_canvas.material = _threshold_mat
	_threshold_vp.add_child(_threshold_canvas)
	_threshold_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Downsample chain
	_down_vps.clear()
	_down_mats.clear()
	_down_canvases.clear()
	var ds_size := res
	for i in range(levels):
		ds_size = Vector2i(maxi(ds_size.x / 2, 1), maxi(ds_size.y / 2, 1))
		var vp := _create_viewport("VP_down%d_%s" % [i, id], ds_size)
		var mat := ShaderMaterial.new()
		mat.shader = _shader_down
		var canvas := TextureRect.new()
		canvas.name = "Canvas_Down%d" % i
		canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		canvas.stretch_mode = TextureRect.STRETCH_SCALE
		canvas.material = mat
		vp.add_child(canvas)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_down_vps.append(vp)
		_down_mats.append(mat)
		_down_canvases.append(canvas)

	# Upsample chain — created in reverse order so that the scene-tree child
	# order matches the data-flow dependency: up[levels-1] renders first
	# (reads from the last downsample VP), then up[levels-2] reads from
	# up[levels-1], and so on down to up[0] which produces full-res output.
	_up_vps.clear()
	_up_mats.clear()
	_up_canvases.clear()
	_up_vps.resize(levels)
	_up_mats.resize(levels)
	_up_canvases.resize(levels)
	for i in range(levels - 1, -1, -1):
		var up_size: Vector2i
		if i == 0:
			up_size = res
		else:
			up_size = _down_vps[i - 1].size
		var vp := _create_viewport("VP_up%d_%s" % [i, id], up_size)
		var mat := ShaderMaterial.new()
		mat.shader = _shader_up
		var canvas := TextureRect.new()
		canvas.name = "Canvas_Up%d" % i
		canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		canvas.stretch_mode = TextureRect.STRETCH_SCALE
		canvas.material = mat
		vp.add_child(canvas)
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_up_vps[i] = vp
		_up_mats[i] = mat
		_up_canvases[i] = canvas

	# Composite pass — uses a TextureRect with original_tex as its .texture so
	# that the canvas is guaranteed to draw even on renderers that skip empty
	# ColorRects.  The shader reads original_tex and glow_tex explicitly.
	_composite_vp = _create_viewport("VP_composite_%s" % id, res)
	_composite_mat = ShaderMaterial.new()
	_composite_mat.shader = _shader_composite
	_composite_canvas = TextureRect.new()
	_composite_canvas.name = "Canvas_Composite"
	_composite_canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_composite_canvas.stretch_mode = TextureRect.STRETCH_SCALE
	_composite_canvas.material = _composite_mat
	_composite_vp.add_child(_composite_canvas)
	_composite_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Mark pipeline as just rebuilt so execute_cook schedules a re-cook
	_pipeline_dirty = true

	# Output texture from composite viewport
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _composite_vp.get_texture()
	_cached_tex_data.viewport = _composite_vp
	_cached_tex_data.resolution = res

	_last_levels = levels
	_initialized = true


func _cleanup_pipeline() -> void:
	# Remove old VPs from the tree immediately (not just queue_free) so they
	# don't participate in the current frame's render pass.  queue_free alone
	# leaves them as children until end-of-frame, polluting the render order.
	for vp in _down_vps:
		if is_instance_valid(vp):
			remove_child(vp)
			vp.queue_free()
	for vp in _up_vps:
		if is_instance_valid(vp):
			remove_child(vp)
			vp.queue_free()
	if is_instance_valid(_threshold_vp):
		remove_child(_threshold_vp)
		_threshold_vp.queue_free()
	if is_instance_valid(_composite_vp):
		remove_child(_composite_vp)
		_composite_vp.queue_free()
	_down_vps.clear()
	_down_mats.clear()
	_down_canvases.clear()
	_up_vps.clear()
	_up_mats.clear()
	_up_canvases.clear()
	_cached_tex_data = null
