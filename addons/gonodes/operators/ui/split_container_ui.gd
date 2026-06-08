class_name SplitContainerUI
extends GNUiBase
## Split container widget for PanelTOP.
##
## Splits two child UI widgets with a draggable divider.
## Outputs widget_state: {"offset": <float>} (split offset in pixels)

var _split: SplitContainer = null
var _managed_children: Array[Control] = []
var _prev_managed: Array[Control] = []


func _init() -> void:
	node_type = "split_container"


func _init_ports() -> void:
	add_input("ui_a", GNFamily.Type.UI, false, "First child widget", "A")
	add_input("ui_b", GNFamily.Type.UI, false, "Second child widget", "B")
	add_output("out", GNFamily.Type.UI, "Container widget output", "Out")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("vertical", false, "Vertical", "Split vertically instead of horizontally"))
	add_parameter(GNParameter.create_int("offset", 0, -1000, 1000, "Offset", "Initial split offset in pixels"))
	add_parameter(GNParameter.create_bool("collapsed", false, "Collapsed", "Collapse second child"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(300, 200), "Min Size", "Minimum container size"))


func _cook(inputs: Array[GNData]) -> GNData:
	var is_vertical: bool = get_param_value("vertical")
	_ensure_split(is_vertical)

	_split.collapsed = get_param_value("collapsed")
	var ms: Vector2i = get_param_value("min_size")
	_split.custom_minimum_size = Vector2(ms.x, ms.y)

	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_populate_children(inputs)
	_remove_stale_children()

	widget_state = {"offset": float(_split.split_offset)}
	return null


func _ensure_split(is_vertical: bool) -> void:
	if _split != null:
		# Check if we need to swap type
		if is_vertical and _split is HSplitContainer:
			_rebuild_split(is_vertical)
		elif not is_vertical and _split is VSplitContainer:
			_rebuild_split(is_vertical)
		return
	_build_split(is_vertical)


func _build_split(is_vertical: bool) -> void:
	if is_vertical:
		_split = VSplitContainer.new()
	else:
		_split = HSplitContainer.new()
	_split.name = id + "_split"
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.split_offset = int(widget_state.get("offset", float(get_param_value("offset"))))
	_register_signal(_split.dragged, _on_dragged)
	_control_node = _split


func _rebuild_split(is_vertical: bool) -> void:
	var children: Array[Control] = []
	for child in _split.get_children():
		children.append(child as Control)
		_split.remove_child(child)
	_cleanup_registered_signals()
	_split.queue_free()
	_build_split(is_vertical)
	for child in children:
		_split.add_child(child)


func _on_dragged(offset: int) -> void:
	widget_state["offset"] = float(offset)
	mark_dirty()


func _populate_children(inputs: Array[GNData]) -> void:
	for data in inputs:
		if data is GNUIData:
			var ctrl: Control = (data as GNUIData).control_node
			if ctrl != null:
				if ctrl.get_parent() != _split:
					if ctrl.get_parent() != null:
						ctrl.get_parent().remove_child(ctrl)
					_split.add_child(ctrl)
				_managed_children.append(ctrl)


func _remove_stale_children() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_children.has(ctrl):
			if ctrl.get_parent() == _split:
				_split.remove_child(ctrl)
	_prev_managed.clear()


func destroy_control_node() -> void:
	_split = null
	super.destroy_control_node()
