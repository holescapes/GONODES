class_name SwitchFIX
extends GNFixtureBase
## Selects one of multiple FIX inputs by index.
## Uses dynamic auto-grow input ports — connect to add more slots.


func _init() -> void:
	super._init()
	node_type = "switch_fix"
	node_description = "Selects one of up to N FIX inputs to pass through, based on an index parameter or expression."


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFixtureBase.FIX_FAMILY, "in", "FIX Input")
	add_output("out", GNFixtureBase.FIX_FAMILY, "Selected fixture")


func _init_parameters() -> void:
	_switch_init_parameters()


func update_dynamic_inputs(connected_ports: PackedInt32Array) -> void:
	super(connected_ports)
	_switch_clamp_index()


func get_active_input_indices() -> PackedInt32Array:
	return _switch_active_indices()


func _cook(inputs: Array[GNData]) -> GNData:
	return _switch_cook(inputs)
