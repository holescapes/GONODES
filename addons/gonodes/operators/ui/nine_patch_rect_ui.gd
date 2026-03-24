class_name NinePatchRectUI
extends GNUiBase
## Nine-patch texture rect widget for PanelTOP.
##
## Displays a TOP input as a stretchable NinePatchRect with configurable margins.
## Outputs widget_state: {"has_texture": 0 or 1}

var _nine: NinePatchRect = null


func _init() -> void:
	node_type = "nine_patch_rect"


func _init_ports() -> void:
	add_input("top", GNFamily.Type.TOP, false, "Texture source")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("patch_left", 8, 0, 256, "Left", "Left patch margin"))
	add_parameter(GNParameter.create_int("patch_top", 8, 0, 256, "Top", "Top patch margin"))
	add_parameter(GNParameter.create_int("patch_right", 8, 0, 256, "Right", "Right patch margin"))
	add_parameter(GNParameter.create_int("patch_bottom", 8, 0, 256, "Bottom", "Bottom patch margin"))
	add_parameter(GNParameter.create_bool("draw_center", true, "Draw Center", "Fill the center patch"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(64, 64), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_nine()

	var has_tex := false
	if inputs.size() > 0 and inputs[0] is GNTextureData:
		var tex_data: GNTextureData = inputs[0] as GNTextureData
		if tex_data.texture != null:
			_nine.texture = tex_data.texture
			has_tex = true
	if not has_tex:
		_nine.texture = null

	_nine.patch_margin_left = get_param_value("patch_left")
	_nine.patch_margin_top = get_param_value("patch_top")
	_nine.patch_margin_right = get_param_value("patch_right")
	_nine.patch_margin_bottom = get_param_value("patch_bottom")
	_nine.draw_center = get_param_value("draw_center")
	var ms: Vector2i = get_param_value("min_size")
	_nine.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {"has_texture": 1.0 if has_tex else 0.0}
	return null


func _ensure_nine() -> void:
	if _nine != null:
		return
	_nine = NinePatchRect.new()
	_nine.name = id + "_ninepatch"
	_nine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nine.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_control_node = _nine
