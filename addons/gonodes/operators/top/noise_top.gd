class_name NoiseTOP
extends GNNode
## Generates a procedural noise texture using a SubViewport and a noise shader.
## Supports simplex noise with configurable scale, offset, seed, and animation.
## SubViewport is a child of this Node — freed automatically on removal.

## Preloaded noise shader resource.
var _shader: Shader = null

## The SubViewport used for rendering this TOP's output (child of this node).
var _viewport: SubViewport = null

## The ColorRect that draws the noise via ShaderMaterial.
var _canvas: ColorRect = null

## The ShaderMaterial applied to the canvas.
var _material: ShaderMaterial = null

## Reusable output data object (created once, updated each cook).
var _cached_tex_data: GNTextureData = null


func _init() -> void:
	node_type = "noise"
	family = GNFamily.Type.TOP
	time_dependent = true
	node_description = "Procedural noise texture (Simplex, Perlin, Voronoi, White). GPU shader."


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Generated noise texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_enum("noise_type",
		PackedStringArray(["Simplex", "Perlin", "Voronoi", "White"]), 0, "", "Noise algorithm"))
	add_parameter(GNParameter.create_float("scale", 4.0, 0.1, 100.0, 0.1, "", "Noise frequency / zoom level"))
	add_parameter(GNParameter.create_vector2("offset", Vector2.ZERO, "", "Spatial offset for panning the noise"))
	add_parameter(GNParameter.create_float("time_offset", 0.0, null, null, 0.01, "", "Z-axis offset for animation (drive with LFO)"))
	add_parameter(GNParameter.create_int("seed", 0, 0, 99999, "", "Random seed for noise variation"))
	add_parameter(GNParameter.create_bool("monochrome", true, "", "Grayscale (on) or RGB color noise (off)"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_viewport()

	var res: Vector2i = get_param_value("resolution")
	var noise_type_idx: int = get_param_value("noise_type")
	var scale_val: float = get_param_value("scale")
	var offset_val: Vector2 = get_param_value("offset")
	var time_off: float = get_param_value("time_offset")
	var seed_val: int = get_param_value("seed")
	var mono: bool = get_param_value("monochrome")

	# Update viewport size
	if _viewport.size != res:
		_viewport.size = res

	# Update shader uniforms
	_material.set_shader_parameter("noise_type", noise_type_idx)
	_material.set_shader_parameter("scale", scale_val)
	_material.set_shader_parameter("offset", offset_val)
	_material.set_shader_parameter("time_offset", time_off)
	_material.set_shader_parameter("seed_val", seed_val)
	_material.set_shader_parameter("monochrome", mono)

	# Update reusable output data (no per-frame allocation)
	_cached_tex_data.resolution = res
	return _cached_tex_data


## Lazily creates the SubViewport + ColorRect + ShaderMaterial rendering pipeline
## as children of this Node.
func _ensure_viewport() -> void:
	if _viewport != null:
		return

	# Load shader
	_shader = load("res://addons/gonodes/shaders/noise_simplex.gdshader") as Shader

	# Create SubViewport as child
	_viewport = SubViewport.new()
	_viewport.name = "VP_%s" % id
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.disable_3d = true
	_viewport.gui_disable_input = true
	add_child(_viewport)

	# Create material
	_material = ShaderMaterial.new()
	_material.shader = _shader

	# Create canvas rect filling the viewport
	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.material = _material
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Create reusable output data — ViewportTexture is a live GPU reference
	_cached_tex_data = GNTextureData.new()
	_cached_tex_data.texture = _viewport.get_texture()
	_cached_tex_data.viewport = _viewport
	_cached_tex_data.resolution = _viewport.size
	GNLogger.debug("NoiseTOP", "'%s' viewport created: %s" % [id, str(_viewport.size)])
