class_name GNTopBase
extends GNNode
## Base class for all TOP (Texture Operator) family operators.
##
## Provides:
##   • family = GNFamily.Type.TOP set automatically
##   • Default output port "out" of type TOP
##   • Input validation via _get_input_top()
##   • Inline texture preview (create_preview_control / update_preview_control)
##   • SubViewport creation + render-once-per-cook lifecycle
##   • Full shader rendering pipeline helper (_init_shader_viewport)
##
## Common members available to all TOPs:
##   _viewport        — primary SubViewport (null until _ensure_viewport / _init_shader_viewport)
##   _material        — ShaderMaterial for the canvas (null for non-shader TOPs)
##   _canvas          — ColorRect or TextureRect filling the viewport
##   _cached_tex_data — reusable GNTextureData wrapping the viewport texture


# ═══════════════════════════════════════════════════════════════════════════════
# Common Viewport Members
# ═══════════════════════════════════════════════════════════════════════════════

## Primary SubViewport for rendering this TOP's output.
var _viewport: SubViewport = null

## ShaderMaterial applied to the canvas (null for non-shader TOPs like Text, Movie).
var _material: ShaderMaterial = null

## Canvas node (ColorRect or TextureRect) that fills the viewport.
var _canvas: Control = null

## Reusable output data wrapping the viewport texture (updated each cook).
var _cached_tex_data: GNTextureData = null


# ═══════════════════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════

func _init() -> void:
	family = GNFamily.Type.TOP


## Ensures family is set even when subclass _init() doesn't call super().
func initialize(p_id: String) -> void:
	if family != GNFamily.Type.NET:
		family = GNFamily.Type.TOP
	super.initialize(p_id)


func _is_family_data(data: GNData) -> bool:
	return data is GNTextureData


## TOPs use SubViewport rendering which requires the main thread.
func requires_main_thread() -> bool:
	return true


## Default output port.  Override _init_ports() in subclass to add inputs
## or extra outputs, but call super._init_ports() first (or add "out" yourself).
func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Texture output")


func create_preview_control() -> Control:
	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tex_rect


func update_preview_control(control: Control) -> void:
	if control is TextureRect:
		if cached_output is GNTextureData:
			(control as TextureRect).texture = (cached_output as GNTextureData).texture
		else:
			(control as TextureRect).texture = null


func render_for_preview(host) -> void:
	if cached_output is GNTextureData:
		var td: GNTextureData = cached_output as GNTextureData
		if td.texture != null:
			host.set_texture(td.texture)
			return
	host.set_text("")


# ═══════════════════════════════════════════════════════════════════════════════
# Input Helpers
# ═══════════════════════════════════════════════════════════════════════════════

## Safely extracts a GNTextureData from the inputs array at [param port].
## Returns null if the port doesn't exist or the data is not GNTextureData.
func _get_input_top(inputs: Array[GNData], port: int = 0) -> GNTextureData:
	if port < inputs.size() and inputs[port] is GNTextureData:
		var _ret0 := inputs[port] as GNTextureData
		return _ret0
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# Viewport Render Control
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the global default TOP resolution from Preferences.
## Operators can use this when creating their resolution parameter:
##   create_vector2i("resolution", _default_resolution(), "Resolution")
static func _default_resolution() -> Vector2i:
	return Vector2i(
		GNSettings.get_value("default_resolution_x", 512),
		GNSettings.get_value("default_resolution_y", 512))

## Creates a SubViewport configured for 2D rendering with sensible defaults.
## Viewports start with [code]UPDATE_DISABLED[/code] — [method execute_cook]
## triggers exactly one render per cook via [code]UPDATE_ONCE[/code].
##
## [param vp_name]        — scene-tree name (e.g. "VP_noise1").
## [param size]           — initial viewport size in pixels.
## [param transparent_bg] — true for compositing (alpha), false for opaque fills.
## [param disable_3d]     — false only for RenderTOP-style 3D viewports.
func _create_viewport(vp_name: String = "", size: Vector2i = Vector2i(512, 512),
		transparent_bg: bool = true, disable_3d: bool = true) -> SubViewport:
	var name := vp_name if not vp_name.is_empty() else ("VP_%s" % id)
	var vp := GNViewportPool.acquire(name, size, transparent_bg, disable_3d)
	add_child(vp)
	return vp


## Swaps [param vp] for a pooled viewport of [param new_size], reparenting
## children and releasing the old instance.  Returns [param vp] unchanged when
## the size already matches.
func _swap_viewport_size(vp: SubViewport, new_size: Vector2i,
		transparent_bg: bool = true, disable_3d: bool = true) -> SubViewport:
	if vp == null or vp.size == new_size:
		return vp
	var vp_name := vp.name
	var old_parent := vp.get_parent()
	var old_index := vp.get_index() if old_parent != null else -1
	var new_vp := GNViewportPool.acquire(vp_name, new_size, transparent_bg, disable_3d)
	if not disable_3d and vp.world_3d != null:
		new_vp.world_3d = vp.world_3d
	while vp.get_child_count() > 0:
		var child := vp.get_child(0)
		vp.remove_child(child)
		new_vp.add_child(child)
	if old_parent != null:
		old_parent.remove_child(vp)
		old_parent.add_child(new_vp)
		if old_index >= 0:
			old_parent.move_child(new_vp, old_index)
	GNViewportPool.release(vp)
	return new_vp


## Resizes [member _viewport] via pool swap and refreshes [member _cached_tex_data].
func _ensure_viewport_size(new_size: Vector2i) -> void:
	if _viewport == null or _viewport.size == new_size:
		return
	var transparent_bg := _viewport.transparent_bg
	var disable_3d := _viewport.disable_3d
	_viewport = _swap_viewport_size(_viewport, new_size, transparent_bg, disable_3d)
	if _cached_tex_data != null:
		_cached_tex_data.texture = _viewport.get_texture()
		_cached_tex_data.viewport = _viewport
		_cached_tex_data.resolution = _viewport.size


func _exit_tree() -> void:
	var to_release: Array[SubViewport] = []
	for child in get_children():
		if child is SubViewport and GNViewportPool.is_pool_managed(child as SubViewport):
			to_release.append(child as SubViewport)
	for vp in to_release:
		GNViewportPool.release(vp)
	_viewport = null


## Lazily creates the primary viewport if it doesn't exist yet.
## Subclasses that only need a SubViewport + GNTextureData (no shader) can call
## this directly.  For the full shader pipeline, use [method _init_shader_viewport].
func _ensure_viewport(size: Vector2i = Vector2i(512, 512),
		transparent_bg: bool = true, disable_3d: bool = true) -> void:
	if _viewport != null:
		return
	_viewport = _create_viewport("", size, transparent_bg, disable_3d)
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size


## Creates the standard shader rendering pipeline used by most TOPs:
## SubViewport → ShaderMaterial(shader) → canvas (ColorRect/TextureRect) → GNTextureData.
##
## [param shader_path]    — resource path to the .gdshader file.
## [param transparent_bg] — true for compositing (alpha), false for opaque fills.
## [param use_texture_rect] — true → TextureRect canvas (for filter TOPs that display
##                            an input texture), false → ColorRect (for generators).
## [param size]           — initial viewport size in pixels.
##
## After calling this, [member _viewport], [member _material], [member _canvas],
## and [member _cached_tex_data] are all ready to use.
func _init_shader_viewport(shader_path: String, transparent_bg: bool = true,
		use_texture_rect: bool = false, size: Vector2i = Vector2i(512, 512)) -> void:
	if _viewport != null:
		return

	_viewport = _create_viewport("", size, transparent_bg)

	# Shader + Material
	var shader: Shader = load(shader_path) as Shader
	_material = ShaderMaterial.new()
	_material.shader = shader

	# Canvas — either TextureRect (filters) or ColorRect (generators)
	if use_texture_rect:
		var tex_rect := TextureRect.new()
		tex_rect.name = "Canvas"
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.material = _material
		_viewport.add_child(tex_rect)
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_canvas = tex_rect
	else:
		var color_rect := ColorRect.new()
		color_rect.name = "Canvas"
		color_rect.material = _material
		_viewport.add_child(color_rect)
		color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_canvas = color_rect

	# Output data
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size


## Overrides [method GNNode.execute_cook] to trigger exactly one render on all
## child SubViewports after [method _cook] completes.  TOPs should create their
## viewports with [code]UPDATE_DISABLED[/code] — the base class handles when to
## render, eliminating wasted GPU work on non-dirty frames.
func execute_cook(inputs: Array[GNData], frame: int) -> GNData:
	var result := super.execute_cook(inputs, frame)
	# After _cook() has set uniforms / textures, request a single render pass
	# on every child SubViewport owned by this TOP.
	if result != null:
		for child in get_children():
			if child is SubViewport:
				child.render_target_update_mode = SubViewport.UPDATE_ONCE
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# GPU-Side Texture Snapshot (Blit Viewport)
# ═══════════════════════════════════════════════════════════════════════════════

## Creates a lightweight SubViewport that copies a source texture via a
## fullscreen TextureRect blit — stays entirely on the GPU, no CPU readback.
## Returns a Dictionary: { "viewport": SubViewport, "canvas": TextureRect }
##
## Call [code]blit.canvas.texture = src[/code] to set the source,
## then [method execute_cook] will trigger UPDATE_ONCE automatically since
## the viewport is a child of this node.
##
## Read back via [code]blit.viewport.get_texture()[/code].
static func _create_blit_viewport(parent: Node, vp_name: String,
		size: Vector2i, transparent: bool = true) -> Dictionary:
	var vp := GNViewportPool.acquire(vp_name, size, transparent, true)
	parent.add_child(vp)

	var canvas := TextureRect.new()
	canvas.name = "BlitCanvas"
	canvas.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.stretch_mode = TextureRect.STRETCH_SCALE
	vp.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return { "viewport": vp, "canvas": canvas }
