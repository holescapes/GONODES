class_name TabBarUI
extends GNUiBase
## Tab bar widget for PanelTOP (tabs only, no child content).
##
## Tab names come from a DAT input (first column).
## Outputs widget_state: {"tab": <float>} (active tab index)

var _tab_bar: TabBar = null


func _init() -> void:
	node_type = "tab_bar"
	node_description = "Tab bar from DAT data. Outputs selected tab index."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "Table: first column = tab names")
	add_output("out", GNFamily.Type.UI, "Widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("default_tab", 0, 0, 32, "Default Tab", "Initially selected tab"))
	add_parameter(GNParameter.create_bool("closable", false, "Closable", "Show close buttons on tabs"))
	add_parameter(GNParameter.create_bool("drag_reorder", false, "Draggable", "Allow drag reordering"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(200, 32), "Min Size", "Minimum widget size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_tab_bar()

	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS if get_param_value("closable") else TabBar.CLOSE_BUTTON_SHOW_NEVER
	_tab_bar.drag_to_rearrange_enabled = get_param_value("drag_reorder")
	var ms: Vector2i = get_param_value("min_size")
	_tab_bar.custom_minimum_size = Vector2(ms.x, ms.y)

	# Rebuild tabs from DAT
	_tab_bar.clear_tabs()
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		for r in range(dat.num_rows()):
			var tab_name: String = dat.cell(r, 0) if dat.num_cols() > 0 else "Tab %d" % r
			_tab_bar.add_tab(tab_name)

	# Restore default selection
	if _tab_bar.tab_count > 0:
		var def: int = get_param_value("default_tab")
		if _tab_bar.current_tab < 0:
			_tab_bar.current_tab = clampi(def, 0, _tab_bar.tab_count - 1)

	widget_state = {"tab": float(_tab_bar.current_tab) if _tab_bar.tab_count > 0 else 0.0}
	return null


func _ensure_tab_bar() -> void:
	if _tab_bar != null:
		return
	_tab_bar = TabBar.new()
	_tab_bar.name = id + "_tabbar"
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_control_node = _tab_bar


func _on_tab_changed(tab: int) -> void:
	widget_state["tab"] = float(tab)
	mark_dirty()


func destroy_control_node() -> void:
	if _tab_bar != null and _tab_bar.tab_changed.is_connected(_on_tab_changed):
		_tab_bar.tab_changed.disconnect(_on_tab_changed)
	_tab_bar = null
	super.destroy_control_node()
