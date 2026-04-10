class_name MarginContainerUI
extends GNUiBase
## Margin wrapper widget for PanelTOP.
##
## Wraps a single child UI widget with configurable margins.
## Outputs widget_state: {} (pure layout, no interactive state).

var _margin: MarginContainer = null
var _managed_child: Control = null


func _init() -> void:
	node_type = "margin_container"


func _init_ports() -> void:
	add_input("ui", GNFamily.Type.UI, false, "Child widget to wrap")
	add_output("out", GNFamily.Type.UI, "Container widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("left", 8, 0, 128, "Left", "Left margin in pixels"))
	add_parameter(GNParameter.create_int("top", 8, 0, 128, "Top", "Top margin in pixels"))
	add_parameter(GNParameter.create_int("right", 8, 0, 128, "Right", "Right margin in pixels"))
	add_parameter(GNParameter.create_int("bottom", 8, 0, 128, "Bottom", "Bottom margin in pixels"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(0, 0), "Min Size", "Minimum container size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_margin()

	_margin.add_theme_constant_override("margin_left", get_param_value("left"))
	_margin.add_theme_constant_override("margin_top", get_param_value("top"))
	_margin.add_theme_constant_override("margin_right", get_param_value("right"))
	_margin.add_theme_constant_override("margin_bottom", get_param_value("bottom"))
	var ms: Vector2i = get_param_value("min_size")
	_margin.custom_minimum_size = Vector2(ms.x, ms.y)

	_populate_child()

	widget_state = {}
	return null


func _ensure_margin() -> void:
	if _margin != null:
		return
	_margin = MarginContainer.new()
	_margin.name = id + "_margin"
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_control_node = _margin


func _populate_child() -> void:
	var new_child: Control = null
	var nodes := get_input_nodes_sorted()
	for upstream in nodes:
		if upstream is GNUiBase:
			new_child = (upstream as GNUiBase).get_control_node()
			break

	# Remove old child if changed
	if _managed_child != null and _managed_child != new_child:
		if is_instance_valid(_managed_child) and _managed_child.get_parent() == _margin:
			_margin.remove_child(_managed_child)
		_managed_child = null

	if new_child != null:
		if new_child.get_parent() != _margin:
			if new_child.get_parent() != null:
				new_child.get_parent().remove_child(new_child)
			_margin.add_child(new_child)
		_managed_child = new_child
