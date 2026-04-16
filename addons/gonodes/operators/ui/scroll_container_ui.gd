class_name ScrollContainerUI
extends GNUiBase
## Scrollable container widget for PanelTOP.
##
## Wraps child UI widgets in a scrollable area.
## Outputs widget_state: {"scroll_h": <float>, "scroll_v": <float>}

var _scroll: ScrollContainer = null
var _inner: VBoxContainer = null
var _managed_children: Array[Control] = []
var _prev_managed: Array[Control] = []


func _init() -> void:
	node_type = "scroll_container"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.UI, "Container widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("h_scroll", true, "H Scroll", "Enable horizontal scrolling"))
	add_parameter(GNParameter.create_bool("v_scroll", true, "V Scroll", "Enable vertical scrolling"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 200), "Min Size", "Minimum container size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_scroll()

	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if get_param_value("h_scroll") else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if get_param_value("v_scroll") else ScrollContainer.SCROLL_MODE_DISABLED
	var ms: Vector2i = get_param_value("min_size")
	_scroll.custom_minimum_size = Vector2(ms.x, ms.y)

	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_populate_children(_inputs)
	_remove_stale_children()

	# Restore scroll position from saved state
	if widget_state.has("scroll_h"):
		_scroll.scroll_horizontal = int(widget_state["scroll_h"])
	if widget_state.has("scroll_v"):
		_scroll.scroll_vertical = int(widget_state["scroll_v"])

	widget_state = {
		"scroll_h": float(_scroll.scroll_horizontal),
		"scroll_v": float(_scroll.scroll_vertical),
	}
	return null


func _ensure_scroll() -> void:
	if _scroll != null:
		return
	_scroll = ScrollContainer.new()
	_scroll.name = id + "_scroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inner = VBoxContainer.new()
	_inner.name = id + "_inner"
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_inner)
	_control_node = _scroll


func _populate_children(inputs: Array[GNData]) -> void:
	for data in inputs:
		if data is GNUIData:
			var ctrl: Control = (data as GNUIData).control_node
			if ctrl != null:
				if ctrl.get_parent() != _inner:
					if ctrl.get_parent() != null:
						ctrl.get_parent().remove_child(ctrl)
					_inner.add_child(ctrl)
				_managed_children.append(ctrl)


func _remove_stale_children() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_children.has(ctrl):
			if ctrl.get_parent() == _inner:
				_inner.remove_child(ctrl)
	_prev_managed.clear()
