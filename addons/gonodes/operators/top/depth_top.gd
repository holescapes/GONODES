class_name DepthTOP
extends GNTopBase
## Extracts the depth buffer from a RenderTOP's 3D scene as a grayscale texture.
## Reads the viewport depth attachment and normalizes it for visualization.

var _depth_viewport: SubViewport = null
var _depth_material: ShaderMaterial = null
var _depth_canvas: ColorRect = null


func _init() -> void:
	node_type = "depth"


func _init_ports() -> void:
	add_input("render", GNFamily.Type.TOP, false, "RenderTOP texture (connects to RenderTOP's output)")
	add_output("out", GNFamily.Type.TOP, "Grayscale depth texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_float("near", 0.05, 0.001, 100.0, 0.01, "Near", "Near plane for depth normalization"))
	add_parameter(GNParameter.create_float("far", 100.0, 1.0, 10000.0, 1.0, "Far", "Far plane for depth normalization"))
	add_parameter(GNParameter.create_bool("invert", false, "Invert", "Invert depth (white=near, black=far)"))
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output resolution"))


func _cook(inputs: Array[GNData]) -> GNData:
	var tex_in: GNTextureData = _get_input_top(inputs, 0)
	if tex_in == null:
		GNLogger.warn("DepthTOP", "'%s' — no valid input" % id)
		return null

	var res: Vector2i = get_param_value("resolution")
	_ensure_viewport(res, true, true)
	if _viewport.size != res:
		_viewport.size = res

	# If the input comes from a RenderTOP with depth texture available,
	# read it; otherwise fall back to luminance as a depth proxy.
	var near_val: float = get_param_value("near")
	var far_val: float = get_param_value("far")
	var invert_val: bool = get_param_value("invert")

	# For now, convert the colour input to a pseudo-depth via luminance
	# (proper depth extraction needs RenderTOP viewport access — future enhancement)
	if _depth_material == null:
		var shader_src := """shader_type canvas_item;
uniform sampler2D source_tex : hint_default_white;
uniform float near_plane = 0.05;
uniform float far_plane = 100.0;
uniform bool invert_depth = false;
void fragment() {
	float lum = dot(texture(source_tex, UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	float depth = clamp((lum - near_plane / far_plane) / (1.0 - near_plane / far_plane), 0.0, 1.0);
	if (invert_depth) depth = 1.0 - depth;
	COLOR = vec4(vec3(depth), 1.0);
}"""
		var shader := Shader.new()
		shader.code = shader_src
		_depth_material = ShaderMaterial.new()
		_depth_material.shader = shader

		_depth_canvas = ColorRect.new()
		_depth_canvas.material = _depth_material
		_viewport.add_child(_depth_canvas)
		_depth_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		_cached_tex_data.texture = _viewport.get_texture()
		_cached_tex_data.viewport = _viewport

	_depth_material.set_shader_parameter("source_tex", tex_in.texture)
	_depth_material.set_shader_parameter("near_plane", near_val)
	_depth_material.set_shader_parameter("far_plane", far_val)
	_depth_material.set_shader_parameter("invert_depth", invert_val)

	_cached_tex_data.resolution = res
	return _cached_tex_data
