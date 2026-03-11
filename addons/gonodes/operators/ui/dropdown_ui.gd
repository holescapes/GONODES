class_name DropdownUI
extends GNUiBase
## Dropdown / combo-box widget for PanelTOP.
##
## Outputs widget_state: {"index": <int>, "value": <float normalized>}

var _option: OptionButton = null


func _init() -> void:
	node_type = "dropdown"
	node_description = "Dropdown menu. Outputs selected index and normalized value."


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Dropdown", "Label", "Display label"))
	add_parameter(GNParameter.create_string("items", "Option A,Option B,Option C", "Items", "Comma-separated list of options"))
	add_parameter(GNParameter.create_int("default_index", 0, 0, 64, "Default", "Initially selected index"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(150, 32), "Min Size", "Minimum widget size"))


func _cook(_inputs: Array[GNData]) -> GNData:
	_ensure_option()

	var items_str: String = get_param_value("items")
	var items: PackedStringArray = items_str.split(",")
	_sync_items(items)

	var ms: Vector2i = get_param_value("min_size")
	_option.custom_minimum_size = Vector2(ms.x, ms.y)

	var idx: int = _option.selected
	var count: int = _option.item_count
	var norm: float = float(idx) / maxf(float(count - 1), 1.0) if count > 0 else 0.0

	widget_state = {
		"index": float(idx),
		"value": norm,
	}

	return null


func _ensure_option() -> void:
	if _option != null:
		return
	_option = OptionButton.new()
	_option.name = id + "_dropdown"
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_item_selected)
	_control_node = _option

	# Populate initial items
	var items_str: String = get_param_value("items")
	for item in items_str.split(","):
		_option.add_item(item.strip_edges())

	var default_idx: int = get_param_value("default_index")
	if default_idx < _option.item_count:
		_option.selected = default_idx


func _sync_items(items: PackedStringArray) -> void:
	# Only rebuild if items changed
	var needs_rebuild: bool = false
	if items.size() != _option.item_count:
		needs_rebuild = true
	else:
		for i in range(items.size()):
			if _option.get_item_text(i) != items[i].strip_edges():
				needs_rebuild = true
				break

	if not needs_rebuild:
		return

	var prev_idx: int = _option.selected
	_option.clear()
	for item in items:
		_option.add_item(item.strip_edges())

	if prev_idx >= 0 and prev_idx < _option.item_count:
		_option.selected = prev_idx
	elif _option.item_count > 0:
		_option.selected = 0


func _on_item_selected(_idx: int) -> void:
	var count: int = _option.item_count
	var norm: float = float(_idx) / maxf(float(count - 1), 1.0) if count > 0 else 0.0
	widget_state["index"] = float(_idx)
	widget_state["value"] = norm
	mark_dirty()


func destroy_control_node() -> void:
	if _option != null and _option.item_selected.is_connected(_on_item_selected):
		_option.item_selected.disconnect(_on_item_selected)
	_option = null
	super.destroy_control_node()
