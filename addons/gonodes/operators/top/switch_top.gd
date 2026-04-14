class_name SwitchTOP
extends GNTopBase
## Selects one of multiple TOP inputs by index.
## For crossfading, use CrossTOP (2-input) or a future BlendTOP (N-input).


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.TOP, "in", "Texture Input")
	add_output("out", GNFamily.Type.TOP, "Selected texture")


func _init_parameters() -> void:
	_switch_init_parameters()


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	_switch_clamp_index()


func get_active_input_indices() -> PackedInt32Array:
	return _switch_active_indices()


func _cook(inputs: Array[GNData]) -> GNData:
	return _switch_cook(inputs)
