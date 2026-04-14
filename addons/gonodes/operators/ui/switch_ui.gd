class_name SwitchUI
extends GNUiBase
## Switches between multiple UI inputs by index.
## Unlike ContainerUI which shows all children, SwitchUI shows only the
## selected input's widget.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "in", "UI Input")
	add_output("out", GNFamily.Type.UI, "Selected UI widget")


func _init_parameters() -> void:
	_switch_init_parameters()


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	_switch_clamp_index()


func get_active_input_indices() -> PackedInt32Array:
	return _switch_active_indices()


func _cook(inputs: Array[GNData]) -> GNData:
	# UI routing goes through get_control_node(), not GNData — custom cook.
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)
	var selected_ui: GNUiBase = null
	var input_nodes := get_input_nodes_sorted()
	if idx < input_nodes.size() and input_nodes[idx] is GNUiBase:
		selected_ui = input_nodes[idx] as GNUiBase

	if selected_ui != null:
		var ctrl: Control = selected_ui.get_control_node()
		if ctrl != null:
			_control_node = ctrl
			widget_state = selected_ui.widget_state.duplicate() if selected_ui.widget_state != null else {}
			return null  # UI output routed via get_control_node()

	_control_node = null
	widget_state = {}
	return null
