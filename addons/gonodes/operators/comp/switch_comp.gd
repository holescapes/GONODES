class_name SwitchCOMP
extends GNCompBase
## Switches between multiple component inputs.
##
## Uses dynamic auto-grow input ports — connect to add more slots,
## disconnect to shrink.  Starts with 2 inputs.


func _init() -> void:
	node_type = "switch"


func _init_ports() -> void:
	_enable_dynamic_inputs(GNFamily.Type.COMP, "in", "Component Input", 2)
	add_output("out", GNFamily.Type.COMP, "Selected component")


func _init_parameters() -> void:
	add_parameter(GNParameter.create_int("index", 0, 0, 0, "Input Index", "Which input to pass through"))
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
	if idx < inputs.size() and inputs[idx] != null:
		return inputs[idx]
	if get_param_value("null_on_missing"):
		return null
	return cached_output
