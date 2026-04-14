class_name SwitchDAT
extends GNDatBase
## Selects one of multiple DAT inputs by index.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.DAT, "in", "Input")
	add_output("out", GNFamily.Type.DAT, "Selected input")


func _init_parameters() -> void:
	_switch_init_parameters()


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	_switch_clamp_index()


func get_active_input_indices() -> PackedInt32Array:
	return _switch_active_indices()


func _cook(inputs: Array[GNData]) -> GNData:
	return _switch_cook(inputs)
