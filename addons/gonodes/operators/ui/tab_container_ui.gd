class_name TabContainerUI
extends GNUiBase
## Tabbed container widget for PanelTOP.
##
## Each UI input becomes a tab page. Tab names come from DAT input or defaults.
## Outputs widget_state: {"tab": <float>} (active tab index)

var _tabs: TabContainer = null
var _managed_children: Array[Control] = []
var _prev_managed: Array[Control] = []


func _init() -> void:
	node_type = "tabcontainer"
	node_description = "Tabbed container. Each UI input is a tab page."


func _init_ports() -> void:
	add_input("dat", GNFamily.Type.DAT, false, "DAT with tab names (one per row)")
	_enable_dynamic_inputs(GNFamily.Type.UI, "ui", "UI Input")
	add_output("out", GNFamily.Type.UI, "Container widget output")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("default_tab", 0, 0, 32, "Default Tab", "Initially selected tab index"))
	add_parameter(GNParameter.create_vector2i("min_size", Vector2i(300, 200), "Min Size", "Minimum container size"))


func _cook(inputs: Array[GNData]) -> GNData:
	_ensure_tabs()

	var ms: Vector2i = get_param_value("min_size")
	_tabs.custom_minimum_size = Vector2(ms.x, ms.y)

	# Gather tab names from DAT input
	var tab_names: PackedStringArray = []
	if inputs.size() > 0 and inputs[0] is GNTableData:
		var dat: GNTableData = inputs[0] as GNTableData
		for r in range(dat.num_rows()):
			tab_names.append(dat.cell(r, 0))

	_prev_managed = _managed_children.duplicate()
	_managed_children.clear()
	_populate_children(tab_names)
	_remove_stale_children()

	widget_state = {"tab": float(_tabs.current_tab) if _tabs.get_tab_count() > 0 else 0.0}
	return null


func _ensure_tabs() -> void:
	if _tabs != null:
		return
	_tabs = TabContainer.new()
	_tabs.name = id + "_tabcontainer"
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_on_tab_changed)
	_control_node = _tabs


func _on_tab_changed(tab: int) -> void:
	widget_state["tab"] = float(tab)
	mark_dirty()


func _populate_children(tab_names: PackedStringArray) -> void:
	var engine: GNCookEngine = get_parent() as GNCookEngine if get_parent() is GNCookEngine else null
	if engine == null or engine.network == null:
		return
	var network: GNNetwork = engine.network
	var conns: Array = network.get_input_connections(id).duplicate()
	# Filter out port 0 (DAT)
	var ui_conns: Array = []
	for conn in conns:
		if conn.to_port > 0:
			ui_conns.append(conn)
	ui_conns.sort_custom(func(a: GNConnection, b: GNConnection) -> bool:
		return a.to_port < b.to_port)

	var idx := 0
	for conn in ui_conns:
		var upstream: GNNode = network.nodes.get(conn.from_node, null)
		if upstream is GNUiBase:
			var ctrl: Control = (upstream as GNUiBase).get_control_node()
			if ctrl != null:
				if ctrl.get_parent() != _tabs:
					if ctrl.get_parent() != null:
						ctrl.get_parent().remove_child(ctrl)
					_tabs.add_child(ctrl)
				# Set tab name
				var tab_idx: int = ctrl.get_index()
				var tab_name: String = tab_names[idx] if idx < tab_names.size() else "Tab %d" % (idx + 1)
				_tabs.set_tab_title(tab_idx, tab_name)
				_managed_children.append(ctrl)
				idx += 1


func _remove_stale_children() -> void:
	for ctrl in _prev_managed:
		if ctrl != null and is_instance_valid(ctrl) and not _managed_children.has(ctrl):
			if ctrl.get_parent() == _tabs:
				_tabs.remove_child(ctrl)
	_prev_managed.clear()


func destroy_control_node() -> void:
	if _tabs != null and _tabs.tab_changed.is_connected(_on_tab_changed):
		_tabs.tab_changed.disconnect(_on_tab_changed)
	_tabs = null
	super.destroy_control_node()
