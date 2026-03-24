class_name MenuButtonUI
extends GNUiBase
## Menu button widget for PanelTOP.
##
## Displays a button that opens a popup menu. Items from DAT input.
## Outputs widget_state: {"selected": <float>} (last selected item index, -1 if none)

var _menu_btn: MenuButton = null
var _last_selected: int = -1


func _init() -> void:
	node_type = "menu_button"


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "Table: first column = menu item text")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_string("label", "Menu", "Label", "Button label text"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(100, 32), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_menu_btn()

	_menu_btn.text = get_param_value("label")
	var ms: Vector2i = get_param_value("min_size")
	_menu_btn.custom_minimum_size = Vector2(ms.x, ms.y)

	# Rebuild popup from DAT
	var popup: PopupMenu = _menu_btn.get_popup()
	popup.clear()
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		for r in range(dat.num_rows()):
			var item_text: String = dat.cell(r, 0) if dat.num_cols() > 0 else "Item %d" % r
			popup.add_item(item_text, r)

	widget_state = {"selected": float(_last_selected)}
	return null


func _ensure_menu_btn() -> void:
	if _menu_btn != null:
		return
	_menu_btn = MenuButton.new()
	_menu_btn.name = id + "_menubtn"
	_menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_btn.flat = false
	var popup: PopupMenu = _menu_btn.get_popup()
	popup.id_pressed.connect(_on_item_pressed)
	_control_node = _menu_btn


func _on_item_pressed(item_id: int) -> void:
	_last_selected = item_id
	widget_state["selected"] = float(item_id)
	mark_dirty()


var _overlay_list: ItemList = null


## Override: show an inline ItemList overlay instead of the PopupMenu.
func _dispatch_panel_input(event: InputEvent) -> void:
	if _menu_btn == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_show_menu_overlay()


func _show_menu_overlay() -> void:
	var popup := _menu_btn.get_popup()
	if popup.item_count == 0:
		return

	var list := ItemList.new()
	list.name = "MenuOverlay"
	for i in range(popup.item_count):
		list.add_item(popup.get_item_text(i))

	var item_h := 28.0
	var list_height := minf(popup.item_count * item_h, 200.0)
	list.custom_minimum_size = Vector2(maxf(_menu_btn.size.x, 120.0), list_height)
	list.size = list.custom_minimum_size

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25, 0.95)
	style.border_color = Color(0.4, 0.4, 0.5, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(list)
	panel.custom_minimum_size = Vector2(maxf(_menu_btn.size.x, 120.0) + 2, list_height + 2)
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
		_on_item_pressed(idx)
	_dismiss_panel_overlay()
	return true


func _on_overlay_dismissed() -> void:
	_overlay_list = null


func destroy_control_node() -> void:
	if _menu_btn != null:
		var popup: PopupMenu = _menu_btn.get_popup()
		if popup != null and popup.id_pressed.is_connected(_on_item_pressed):
			popup.id_pressed.disconnect(_on_item_pressed)
	_menu_btn = null
	super.destroy_control_node()
