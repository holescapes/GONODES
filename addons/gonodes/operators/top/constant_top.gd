class_name ConstantTOP
extends GNTopBase
## Generates a solid color texture. No shader needed.


func _init() -> void:
	node_type = "constant"


func _init_ports() -> void:
	add_output("out", GNFamily.Type.TOP, "Solid color texture")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_vector2i("resolution", Vector2i(512, 512), "", "Output texture resolution in pixels"))
	add_parameter(GNParameter.create_color("color", Color.BLACK, "", "Fill color"))
	add_parameter(GNParameter.create_float("alpha", 1.0, 0.0, 1.0, 0.01, "", "Alpha override"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_setup_viewport()

	var res: Vector2i = get_param_value("resolution")
	var col: Color = get_param_value("color")
	var alpha_val: float = get_param_value("alpha")

	if _viewport.size != res:
		_viewport.size = res

	col.a = alpha_val
	_canvas.color = col

	_cached_tex_data.resolution = res
	return _cached_tex_data


func _setup_viewport() -> void:
	if _viewport != null:
		return

	_ensure_viewport(get_param_value("resolution"))

	_canvas = ColorRect.new()
	_canvas.name = "Canvas"
	_canvas.color = Color.BLACK
	_viewport.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
