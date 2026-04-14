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
	var idx: int = clampi(get_param_value("index"), 0, inputs.size() - 1)
	if idx < inputs.size() and inputs[idx] is GNUIData:
		var ctrl: Control = (inputs[idx] as GNUIData).control_node
		if ctrl != null:
			_control_node = ctrl
			widget_state = {}
			return null
	_control_node = null
	widget_state = {}
	return null
