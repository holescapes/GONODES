class_name ColorRectUI
extends GNUiBase
## Colored rectangle widget for PanelTOP.
##
## Displays a solid color or applies a ShaderMaterial via MAT input.
## Useful as a clickable colored area or shader canvas inside a panel.
## Outputs widget_state: {"click": 0 or 1}

var _color_rect: ColorRect = null
var _click_value: float = 0.0


func _init() -> void:
	node_type = "color_rect"


func _init_ports() -> void:
	add_input("mat", GNFamily.Type.MAT, false, "Shader material overlay", "Material")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_color("color", Color(0.2, 0.2, 0.25), "Color", "Fill color"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 200), "Min Size", "Minimum rect size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_color_rect()

	_color_rect.color = get_param_value("color")
	var ms: Vector2i = get_param_value("min_size")
	_color_rect.custom_minimum_size = Vector2(ms.x, ms.y)

	# MAT input → material
	if inputs.size() > 0 and inputs[0] is GNMaterialData:
		var mat_data: GNMaterialData = inputs[0] as GNMaterialData
		_color_rect.material = mat_data.material
	else:
		_color_rect.material = null

	widget_state = {"click": _click_value}
	_click_value = 0.0
	return null


func _ensure_color_rect() -> void:
	if _color_rect != null:
		return
	_color_rect = ColorRect.new()
	_color_rect.name = id + "_colorrect"
	_color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_register_signal(_color_rect.gui_input, _on_input)
	_control_node = _color_rect


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_click_value = 1.0
			widget_state["click"] = 1.0
			mark_dirty()


func destroy_control_node() -> void:
	_color_rect = null
	super.destroy_control_node()
