class_name SwitchUI
extends GNUiBase
## Switches between multiple UI inputs based on an index.
## Uses dynamic auto-grow input ports — connect to add more slots.
##
## Unlike ContainerUI which shows all children at once, SwitchUI
## shows only the selected input's widget. Useful for toggling
## between different control panels programmatically.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.UI, "in", "UI Input")
	add_output("out", GNFamily.Type.UI, "Selected UI widget")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Index",
		"Which input to output (0-based)"))
	add_parameter(GNParameter.create_bool("null_on_missing", false, "Null on Missing",
		"When true, output null instead of holding the previous frame when the selected input is empty. Useful as a programmatic gate."))


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	var idx_param := get_parameter("index")
	if idx_param:
		var max_idx: int = maxi(input_ports.size() - 2, 0)
		idx_param.max_value = max_idx
		if int(idx_param.value) > max_idx:
			idx_param.set_value(max_idx)


func get_active_input_indices() -> PackedInt32Array:
	var idx: int = clampi(get_param_value("index"), 0, maxi(input_ports.size() - 1, 0))
	return PackedInt32Array([idx])


func _cook(inputs: Array[GNData]) -> GNData:
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)

	# Find the selected upstream UI node and adopt its control
	var selected_ui: GNUiBase = null
	var input_nodes := get_input_nodes_sorted()
	if idx < input_nodes.size() and input_nodes[idx] is GNUiBase:
		selected_ui = input_nodes[idx] as GNUiBase

	if selected_ui != null:
		var ctrl: Control = selected_ui.get_control_node()
		if ctrl != null:
			_control_node = ctrl
			widget_state = selected_ui.widget_state.duplicate() if selected_ui.widget_state != null else {}
			return null  # UI cook returns null; output is routed via get_control_node()

	_control_node = null
	widget_state = {}
	return null
