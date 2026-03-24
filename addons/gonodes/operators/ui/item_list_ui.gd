class_name ItemListUI
extends GNUiBase
## Item list widget for PanelTOP.
##
## Populates from a DAT input (first column = item text).
## Optional TOP input supplies icon texture for all items.
## Outputs widget_state: {"selected": <float>} (selected index, -1 if none)

var _list: ItemList = null


func _init() -> void:
	node_type = "item_list"


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "Table: first column = item text")
	add_input("top", GNFamily.Type.TOP, false, "Icon texture for items")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_bool("allow_reselect", false, "Reselect", "Allow clicking already selected item"))
	add_parameter(GNParameter.create_int("max_columns", 1, 1, 16, "Columns", "Max columns (0 = auto)"))
	add_parameter(GNParameter.create_int("icon_size", 32, 8, 128, "Icon Size", "Fixed icon size in pixels"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 200), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_list()

	_list.allow_reselect = get_param_value("allow_reselect")
	_list.max_columns = get_param_value("max_columns")
	var icon_sz: int = get_param_value("icon_size")
	_list.fixed_icon_size = Vector2i(icon_sz, icon_sz)
	var ms: Vector2i = get_param_value("min_size")
	_list.custom_minimum_size = Vector2(ms.x, ms.y)

	# Get icon from TOP
	var icon: Texture2D = null
	if inputs.size() > 1 and inputs[1] is GNTextureData:
		var tex_data: GNTextureData = inputs[1] as GNTextureData
		icon = tex_data.texture

	# Rebuild list from DAT
	_list.clear()
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		for r in range(dat.num_rows()):
			var item_text: String = dat.cell(r, 0) if dat.num_cols() > 0 else ""
			_list.add_item(item_text, icon)

	var selected: Array[int] = _list.get_selected_items()
	var idx: int = selected[0] if selected.size() > 0 else -1

	widget_state = {"selected": float(idx)}
	return null


func _ensure_list() -> void:
	if _list != null:
		return
	_list = ItemList.new()
	_list.name = id + "_itemlist"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_item_selected)
	_control_node = _list


func _on_item_selected(index: int) -> void:
	widget_state["selected"] = float(index)
	mark_dirty()


func destroy_control_node() -> void:
	if _list != null and _list.item_selected.is_connected(_on_item_selected):
		_list.item_selected.disconnect(_on_item_selected)
	_list = null
	super.destroy_control_node()
