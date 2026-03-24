class_name DropdownUI
extends GNUiBase
## Dropdown / combo-box widget for PanelTOP.
##
## Outputs widget_state: {"index": <int>, "value": <float normalized>}

var _option: OptionButton = null


func _init() -> void:
	node_type = "dropdown"


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
		"hover": widget_state.get("hover", 0.0),
	}

	return null


func _ensure_option() -> void:
	if _option != null:
		return
	_option = OptionButton.new()
	_option.name = id + "_dropdown"
	_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option.item_selected.connect(_on_item_selected)
	_option.mouse_entered.connect(_on_hover_changed.bind(true))
	_option.mouse_exited.connect(_on_hover_changed.bind(false))
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


## Override: show an inline ItemList overlay instead of the OptionButton popup.
func _dispatch_panel_input(event: InputEvent) -> void:
	if _option == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_show_dropdown_overlay()


var _overlay_list: ItemList = null


func _show_dropdown_overlay() -> void:
	if _option.item_count == 0:
		return

	var list := ItemList.new()
	list.name = "DropdownOverlay"
	for i in range(_option.item_count):
		list.add_item(_option.get_item_text(i))
	if _option.selected >= 0 and _option.selected < list.item_count:
		list.select(_option.selected)

	var item_h := 28.0
	var list_height := minf(_option.item_count * item_h, 200.0)
	list.custom_minimum_size = Vector2(_option.size.x, list_height)
	list.size = list.custom_minimum_size

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(list)
	panel.custom_minimum_size = Vector2(_option.size.x + 2, list_height + 2)
	panel.size = panel.custom_minimum_size

	_overlay_list = list
	_request_panel_overlay(panel)


func _handle_overlay_input(event: InputEvent) -> bool:
	if _overlay_list == null:
		return false
	if not (event is InputEventMouseButton):
		return false
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return false

	var list_rect := _overlay_list.get_global_rect()
	var local_pos := mb.position - list_rect.position
	var idx := _overlay_list.get_item_at_position(local_pos, true)
	if idx >= 0:
		_option.select(idx)
		_option.emit_signal("item_selected", idx)
	_dismiss_panel_overlay()
	return true


func _on_overlay_dismissed() -> void:
	_overlay_list = null


func _on_hover_changed(hovered: bool) -> void:
	widget_state["hover"] = 1.0 if hovered else 0.0
	mark_dirty()


func destroy_control_node() -> void:
	if _option != null:
		if _option.item_selected.is_connected(_on_item_selected):
			_option.item_selected.disconnect(_on_item_selected)
		if _option.mouse_entered.is_connected(_on_hover_changed):
			_option.mouse_entered.disconnect(_on_hover_changed)
		if _option.mouse_exited.is_connected(_on_hover_changed):
			_option.mouse_exited.disconnect(_on_hover_changed)
	_option = null
	super.destroy_control_node()
