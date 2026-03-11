class_name MenuButtonUI
extends GNUiBase
## Menu button widget for PanelTOP.
##
## Displays a button that opens a popup menu. Items from DAT input.
## Outputs widget_state: {"selected": <float>} (last selected item index, -1 if none)

var _menu_btn: MenuButton = null
var _last_selected: int = -1


func _init() -> void:
	node_type = "menubutton"
	node_description = "Button with popup menu from DAT data."


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


func destroy_control_node() -> void:
	if _menu_btn != null:
		var popup: PopupMenu = _menu_btn.get_popup()
		if popup != null and popup.id_pressed.is_connected(_on_item_pressed):
			popup.id_pressed.disconnect(_on_item_pressed)
	_menu_btn = null
	super.destroy_control_node()
