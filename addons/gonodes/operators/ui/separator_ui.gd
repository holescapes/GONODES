class_name SeparatorUI
extends GNUiBase
## Separator widget for PanelTOP.
##
## Horizontal or vertical separating line for layout.
## Outputs widget_state: {} (no interactive state).

var _sep: Separator = null
var _current_vertical: bool = false


func _init() -> void:
	node_type = "separator"


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("vertical", false, "Vertical", "Use vertical separator"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(0, 0), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	var is_vertical: bool = get_param_value("vertical")
	_ensure_sep(is_vertical)

	var ms: Vector2i = get_param_value("min_size")
	_sep.custom_minimum_size = Vector2(ms.x, ms.y)

	widget_state = {}
	return null


func _ensure_sep(is_vertical: bool) -> void:
	if _sep != null and _current_vertical == is_vertical:
		return

	if _sep != null:
		var parent: Node = _sep.get_parent()
		if parent != null:
			parent.remove_child(_sep)
		_sep.queue_free()
		_sep = null

	if is_vertical:
		_sep = VSeparator.new()
	else:
		_sep = HSeparator.new()
	_sep.name = id + "_sep"
	_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current_vertical = is_vertical
	_control_node = _sep
